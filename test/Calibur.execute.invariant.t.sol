// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Test} from "forge-std/Test.sol";
import {TokenHandler} from "./utils/TokenHandler.sol";
import {ExecuteFixtures} from "./utils/ExecuteFixtures.sol";
import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {TestKeyManager, TestKey} from "./utils/TestKeyManager.sol";
import {ICalibur} from "../src/interfaces/ICalibur.sol";
import {INonceManager} from "../src/interfaces/INonceManager.sol";
import {IERC7821} from "../src/interfaces/IERC7821.sol";
import {IKeyManagement} from "../src/interfaces/IKeyManagement.sol";
import {Call, CallLib} from "../src/libraries/CallLib.sol";
import {KeyType, Key, KeyLib} from "../src/libraries/KeyLib.sol";
import {HandlerCall, CallUtils} from "./utils/CallUtils.sol";
import {FunctionCallGenerator} from "./utils/FunctionCallGenerator.sol";
import {Settings, SettingsLib} from "../src/libraries/SettingsLib.sol";
import {SettingsBuilder} from "./utils/SettingsBuilder.sol";
import {SignedBatchedCall, SignedBatchedCallLib} from "../src/libraries/SignedBatchedCallLib.sol";
import {InvariantRevertLib} from "./utils/InvariantRevertLib.sol";
import {InvariantBlock} from "./utils/InvariantFixtures.sol";
import {BaseAuthorization} from "../src/BaseAuthorization.sol";
import {BatchedCall} from "../src/libraries/BatchedCallLib.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

// To avoid stack to deep
struct SetupParams {
    ICalibur _signerAccount;
    TestKey[] _signingKeys;
    address _tokenA;
    address _tokenB;
}

contract CaliburExecuteInvariantHandler is ExecuteFixtures, FunctionCallGenerator {
    using TestKeyManager for TestKey;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using KeyLib for Key;
    using CallLib for Call[];
    using CallUtils for *;
    using SignedBatchedCallLib for SignedBatchedCall;
    using SettingsBuilder for Settings;
    using SettingsLib for Settings;
    using InvariantRevertLib for bytes[];

    /// @notice The keys which will be used to sign calls to execute
    TestKey[] public signingKeys;
    TestKey public currentSigningKey;

    ERC20Mock public tokenA;
    ERC20Mock public tokenB;

    bytes4 public constant EXECUTE_BATCHED_CALLS_SELECTOR =
        bytes4(keccak256("execute(((address,uint256,bytes)[],uint256,bytes32,bool,bytes),bytes)"));
    bytes4 public constant EXECUTE_SIGNED_BATCHED_CALL_SELECTOR =
        bytes4(keccak256("execute((((address,uint256,bytes)[],bool),uint256,bytes32),bytes)"));

    constructor(SetupParams memory _params)
        FunctionCallGenerator(_params._signerAccount, _params._tokenA, _params._tokenB)
    {
        for (uint256 i = 0; i < _params._signingKeys.length; i++) {
            signingKeys.push(_params._signingKeys[i]);
            fixtureKeys.push(_params._signingKeys[i]);
        }
        tokenA = ERC20Mock(_params._tokenA);
        tokenB = ERC20Mock(_params._tokenB);
    }

    /// @notice Sets the current key for the test
    /// if the test uses `caller`, we prank the key's public key
    modifier useKey() {
        currentSigningKey = _randKeyFromArray(signingKeys);
        _;
    }

    modifier setBlock() {
        InvariantBlock memory _block = _randBlock();
        if (_block.blockNumber != block.number) {
            vm.roll(_block.blockNumber);
        }
        if (_block.blockTimestamp != block.timestamp) {
            vm.warp(_block.blockTimestamp);
        }
        _;
    }

    /// Helper function to get the next available nonce
    function _buildNextValidNonce(uint256 key) internal view returns (uint256 nonce, uint64 seq) {
        seq = uint64(signerAccount.getSeq(key));
        nonce = key << 64 | seq;
    }

    /// @notice Executes a batched call with the current caller
    /// @dev Handler function meant to be called during invariant tests
    /// TODO: only supports single call arrays for now
    /// - Generates a random call, executes it, then processes any registered callbacks
    /// - Any reverts are expected by the generated handler call
    function executeBatchedCall() public useKey setBlock {
        address caller = vm.addr(currentSigningKey.privateKey);
        bool isRootKey = vm.addr(currentSigningKey.privateKey) == address(signerAccount);

        bytes32 callerKeyHash = isRootKey ? KeyLib.ROOT_KEY_HASH : currentSigningKey.toKeyHash();

        vm.startPrank(caller);
        HandlerCall[] memory handlerCalls = _generateHandlerCalls(MAX_CALL_SIZE);

        bytes[] memory expectedReverts = InvariantRevertLib.initArray();

        BatchedCall memory batchedCall =
            CallUtils.initBatchedCall().withCalls(handlerCalls.toCalls()).withRevertOnFailure(true);

        Settings callerSettings;
        bool isRegisteredCaller;
        try signerAccount.getKey(callerKeyHash) {
            isRegisteredCaller = true;
            callerSettings = signerAccount.getKeySettings(callerKeyHash);
        } catch (bytes memory revertData) {
            isRegisteredCaller = false;
            assertEq(bytes4(revertData), IKeyManagement.KeyDoesNotExist.selector);
        }

        // Top level validation checks
        (bool isExpired,) = callerSettings.isExpired();
        if (!isRegisteredCaller || (caller != address(signerAccount) && isExpired)) {
            expectedReverts = expectedReverts.push(abi.encodeWithSelector(BaseAuthorization.Unauthorized.selector));
        } else if (!callerSettings.isAdmin() && batchedCall.calls.containsSelfCall()) {
            expectedReverts = expectedReverts.push(abi.encodeWithSelector(IKeyManagement.OnlyAdminCanSelfCall.selector));
        }

        for (uint256 i = 0; i < handlerCalls.length; i++) {
            if (handlerCalls[i].revertData.length > 0) {
                expectedReverts = expectedReverts.push(handlerCalls[i].revertData);
            }
        }

        try signerAccount.execute(batchedCall) {
            _processCallbacks(handlerCalls);
        } catch (bytes memory revertData) {
            if (expectedReverts.length > 0) {
                assertEq(revertData, expectedReverts[0]);
            } else {
                bytes memory debugCalldata =
                    abi.encodeWithSelector(EXECUTE_BATCHED_CALLS_SELECTOR, handlerCalls.toCalls(), true);
                console2.logBytes(debugCalldata);
                console2.logBytes(revertData);
                revert("uncaught revert");
            }
        }

        vm.stopPrank();
    }

    /// @notice Executes a call with operation data (with signature)
    /// @dev Handler function meant to be called during invariant tests
    /// - If the signing key is not registered on the account, expect the call to revert
    function executeSignedBatchedCall(uint192 nonceKey) public useKey setBlock {
        bool isRootKey = vm.addr(currentSigningKey.privateKey) == address(signerAccount);
        bytes32 currentKeyHash = isRootKey ? KeyLib.ROOT_KEY_HASH : currentSigningKey.toKeyHash();

        HandlerCall[] memory handlerCalls = _generateHandlerCalls(MAX_CALL_SIZE);
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);
        Call[] memory calls = handlerCalls.toCalls();

        // TODO: remove the hardcoded revertOnFailure once we can test for it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall =
            CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall).withKeyHash(currentKeyHash).withNonce(nonce);

        bytes memory emptyHookData = abi.encode("");
        bytes32 digest = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = abi.encode(currentSigningKey.sign(digest), emptyHookData);

        bytes[] memory expectedReverts = InvariantRevertLib.initArray();

        // Add signature validation reverts since they are checked first
        if (!isRootKey) {
            try signerAccount.getKey(currentKeyHash) {
                Settings settings = signerAccount.getKeySettings(currentKeyHash);
                // Expect revert if expired
                (bool isExpired,) = settings.isExpired();
                if (isExpired) {
                    _state.validationFailed_KeyExpired++;
                    expectedReverts = expectedReverts.push(abi.encodeWithSelector(IKeyManagement.KeyExpired.selector));
                } else if (!settings.isAdmin() && batchedCall.calls.containsSelfCall()) {
                    _state.validationFailed_OnlyAdminCanSelfCall++;
                    expectedReverts =
                        expectedReverts.push(abi.encodeWithSelector(IKeyManagement.OnlyAdminCanSelfCall.selector));
                }
            } catch (bytes memory revertData) {
                _state.validationFailed_KeyDoesNotExist++;
                assertEq(bytes4(revertData), IKeyManagement.KeyDoesNotExist.selector);
                expectedReverts = expectedReverts.push(abi.encodeWithSelector(IKeyManagement.KeyDoesNotExist.selector));
            }
        }
        // Add any expected execution level reverts
        for (uint256 i = 0; i < handlerCalls.length; i++) {
            if (handlerCalls[i].revertData.length > 0) {
                expectedReverts = expectedReverts.push(handlerCalls[i].revertData);
            }
        }

        try signerAccount.execute(signedBatchedCall, signature) {
            _processCallbacks(handlerCalls);
        } catch (bytes memory revertData) {
            if (expectedReverts.length > 0) {
                // Only assert against the first expected revert
                assertEq(revertData, expectedReverts[0]);
            } else {
                bytes memory debugCalldata =
                    abi.encodeWithSelector(EXECUTE_SIGNED_BATCHED_CALL_SELECTOR, signedBatchedCall, signature);
                console2.logBytes(debugCalldata);
                console2.logBytes(revertData);
                revert("uncaught revert");
            }
        }
    }
}

/// @title CaliburExecuteInvariantTest
contract CaliburExecuteInvariantTest is TokenHandler, DelegationHandler {
    using KeyLib for *;
    using TestKeyManager for TestKey;
    using CallUtils for Call;
    using CallUtils for Call[];

    CaliburExecuteInvariantHandler internal invariantHandler;

    address public untrustedCaller = makeAddr("untrustedCaller");
    uint256 public untrustedPrivateKey = 0xdead;

    address internal sender = makeAddr("sender");

    function setUp() public {
        setUpDelegation();
        setUpTokens();

        vm.deal(address(signerAccount), 100e18);
        tokenA.mint(address(signerAccount), 100e18);
        tokenB.mint(address(signerAccount), 100e18);

        TestKey[] memory _signingKeys = new TestKey[](2);
        // Add trusted root key
        _signingKeys[0] = TestKeyManager.withSeed(KeyType.Secp256k1, signerPrivateKey);
        // Add untrusted key
        _signingKeys[1] = TestKeyManager.withSeed(KeyType.Secp256k1, untrustedPrivateKey);

        SetupParams memory params = SetupParams({
            _signerAccount: signerAccount,
            _signingKeys: _signingKeys,
            _tokenA: address(tokenA),
            _tokenB: address(tokenB)
        });
        invariantHandler = new CaliburExecuteInvariantHandler(params);

        // Explicitly target the wrapped execute functions in the handler
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = CaliburExecuteInvariantHandler.executeBatchedCall.selector;
        selectors[1] = CaliburExecuteInvariantHandler.executeSignedBatchedCall.selector;
        FuzzSelector memory selector = FuzzSelector({addr: address(invariantHandler), selectors: selectors});

        targetSelector(selector);
        targetContract(address(invariantHandler));

        // Sender is the address used to call the invariantHandler, not important
        targetSender(sender);
    }

    /// Function called after each invariant test
    function afterInvariant() public view {
        console2.log("Number of persisted registered keys");
        console2.logUint(signerAccount.keyCount());

        invariantHandler.logState();
    }

    /// @notice Verifies that the root key can always register other signing keys
    function invariant_rootKeyCanAlwaysRegisterOtherSigningKeys() public {
        TestKey memory newKey = TestKeyManager.withSeed(KeyType.Secp256k1, vm.randomUint());
        bytes32 newKeyHash = newKey.toKeyHash();
        // Assume that the random key is not a protected address
        vm.assume(
            newKeyHash != KeyLib.ROOT_KEY_HASH && newKeyHash != signerAccount.ENTRY_POINT().toKeyHash()
                && newKeyHash != address(IEntryPoint(signerAccount.ENTRY_POINT()).senderCreator()).toKeyHash()
        );
        vm.prank(address(signerAccount));
        signerAccount.register(newKey.toKey());
        assertEq(signerAccount.getKey(newKey.toKeyHash()).hash(), newKey.toKeyHash());
    }

    function invariant_keyStateIsConsistent() public view {
        // Iterate over keyHashes
        uint256 keyCount = signerAccount.keyCount();
        for (uint256 i = 0; i < keyCount; i++) {
            // Will revert if key does not exist
            Key memory key = signerAccount.keyAt(i);
            bytes32 keyHash = key.hash();
            // Will be false if the stored encoded data is wrong
            assertEq(signerAccount.getKey(keyHash).hash(), keyHash);
        }
    }
}
