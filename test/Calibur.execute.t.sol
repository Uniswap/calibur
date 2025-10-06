// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {TokenHandler} from "./utils/TokenHandler.sol";
import {ExecuteFixtures} from "./utils/ExecuteFixtures.sol";
import {HookHandler} from "./utils/HookHandler.sol";
import {Call} from "../src/libraries/CallLib.sol";
import {CallLib} from "../src/libraries/CallLib.sol";
import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {HandlerCall, CallUtils} from "./utils/CallUtils.sol";
import {IERC7821} from "../src/interfaces/IERC7821.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Errors} from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {EIP712} from "../src/EIP712.sol";
import {CallLib} from "../src/libraries/CallLib.sol";
import {NonceManager} from "../src/NonceManager.sol";
import {INonceManager} from "../src/interfaces/INonceManager.sol";
import {TestKeyManager, TestKey} from "./utils/TestKeyManager.sol";
import {KeyType, KeyLib, Key} from "../src/libraries/KeyLib.sol";
import {IKeyManagement} from "../src/interfaces/IKeyManagement.sol";
import {SignedBatchedCallLib, SignedBatchedCall} from "../src/libraries/SignedBatchedCallLib.sol";
import {Settings, SettingsLib} from "../src/libraries/SettingsLib.sol";
import {SettingsBuilder} from "./utils/SettingsBuilder.sol";
import {ICalibur} from "../src/interfaces/ICalibur.sol";
import {BaseAuthorization} from "../src/BaseAuthorization.sol";
import {BatchedCall} from "../src/libraries/BatchedCallLib.sol";

contract CaliburExecuteTest is TokenHandler, HookHandler, ExecuteFixtures, DelegationHandler {
    using TestKeyManager for TestKey;
    using KeyLib for Key;
    using CallUtils for *;
    using CallLib for Call[];
    using SignedBatchedCallLib for SignedBatchedCall;
    using SettingsLib for Settings;
    using SettingsBuilder for Settings;

    address receiver = makeAddr("receiver");

    function setUp() public {
        setUpDelegation();
        setUpTokens();
        setUpHooks();

        vm.deal(address(signerAccount), 100e18);
        tokenA.mint(address(signerAccount), 100e18);
        tokenB.mint(address(signerAccount), 100e18);
    }

    /// Helper function to get the next available nonce
    function _buildNextValidNonce(uint256 key) internal view returns (uint256 nonce, uint64 seq) {
        seq = uint64(signerAccount.getSeq(key));
        nonce = key << 64 | seq;
    }

    function test_supportsExecutionMode_fuzz(bytes32 _mode) public view {
        assertEq(signerAccount.supportsExecutionMode(_mode), _mode == BATCHED_CALL || _mode == BATCHED_CAN_REVERT_CALL);
    }

    function test_execute_reverts_withUnsupportedExecutionMode() public {
        // Test specific modes since the fuzz is just over the first 2 bytes.
        bytes32[] memory modes = new bytes32[](3);
        bytes32 invalid_mode_1 = 0x0101100000000000000000000000000000000000000000000000000000000000;
        bytes32 invalid_mode_2 = 0x0100000000000a00000000000000000000000000000000000000000000000000;
        bytes32 invalid_mode_3 = 0x010100000000000000000000000000000000000000000000000000000000000a;
        modes[0] = invalid_mode_1;
        modes[1] = invalid_mode_2;
        modes[2] = invalid_mode_3;

        vm.startPrank(address(signerAccount));
        for (uint256 i = 0; i < modes.length; i++) {
            bytes32 mode = modes[i];
            vm.expectRevert(IERC7821.UnsupportedExecutionMode.selector);
            signerAccount.execute(mode, abi.encode(CallUtils.initArray()));
        }
        vm.stopPrank();
    }

    function test_execute_fuzz_reverts(uint16 _mode) public {
        uint256 zeros = uint256(0);
        bytes32 mode = bytes32(uint256(_mode) << 240 | zeros);
        vm.prank(address(signerAccount));
        if (mode != BATCHED_CALL && mode != BATCHED_CAN_REVERT_CALL) {
            vm.expectRevert(IERC7821.UnsupportedExecutionMode.selector);
        }
        signerAccount.execute(mode, abi.encode(CallUtils.initArray()));
    }

    function test_execute_auth_reverts() public {
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(CallUtils.initBatchedCall().withRevertOnFailure(true));
    }

    function test_execute_erc7821() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 1e18));

        bytes memory executionData = abi.encode(calls);

        assertEq(tokenA.balanceOf(address(signerAccount)), 100e18);
        assertEq(tokenB.balanceOf(address(signerAccount)), 100e18);

        uint256 nativeBalanceBefore = address(signerAccount).balance;

        vm.prank(address(signerAccount));
        signerAccount.execute(BATCHED_CALL, executionData);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
        assertEq(tokenB.balanceOf(address(receiver)), 1e18);
        // native balance should not change
        assertEq(address(signerAccount).balance, nativeBalanceBefore);
    }

    function test_execute_erc7821_native() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        calls = calls.push(buildTransferCall(address(0), address(receiver), 1e18));

        bytes memory executionData = abi.encode(calls);

        vm.prank(address(signerAccount));
        signerAccount.execute(BATCHED_CALL, executionData);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
        assertEq(address(receiver).balance, 1e18);
    }

    function test_execute_erc7821_batch_reverts() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        // this call should cause the entire batch to revert
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 101e18));

        bytes memory executionData = abi.encode(calls);

        vm.prank(address(signerAccount));
        bytes memory balanceError = abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector, address(signerAccount), 100e18, 101e18
        );
        vm.expectRevert(abi.encodeWithSelector(ICalibur.CallFailed.selector, balanceError));
        signerAccount.execute(BATCHED_CALL, executionData);
    }

    function test_execute_erc7821_batch_canRevert_succeeds() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        // this call reverts but the batch should succeed
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 101e18));

        bytes memory executionData = abi.encode(calls);

        vm.prank(address(signerAccount));
        signerAccount.execute(BATCHED_CAN_REVERT_CALL, executionData);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
        // the second transfer failed
        assertEq(tokenB.balanceOf(address(receiver)), 0);
    }

    function test_execute_withSignature_addressZero_invalidSignature_reverts() public {
        TestKey memory addressZeroKey =
            TestKey({keyType: KeyType.Secp256k1, publicKey: abi.encode(0, 0), privateKey: uint256(0)});

        vm.prank(address(signerAccount));
        signerAccount.register(addressZeroKey.toKey());

        // Transfer the whole balance of tokenB
        uint256 userBalanceTokenB = tokenB.balanceOf(address(signerAccount));
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), userBalanceTokenB));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(addressZeroKey.toKeyHash());

        // Use a dummy signature that is at least 64 bytes
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1234, keccak256("invalidDigest"));
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        vm.expectRevert(ICalibur.InvalidSignature.selector);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
    }

    function test_execute_batchedCall_owner() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 1e18));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        vm.prank(address(signerAccount));
        signerAccount.execute(batchedCall);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
        assertEq(tokenB.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_batchedCall_owner_revertOnFailureFalse_succeeds() public {
        uint256 tokenBalance = tokenA.balanceOf(address(signerAccount));
        Call[] memory calls = CallUtils.initArray();
        // Transfer more than signerAccount's balance
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), tokenBalance + 1));
        // Set revertOnFailure to false, so the batch should succeed even if the transfer reverts
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(false);

        vm.prank(address(signerAccount));
        signerAccount.execute(batchedCall);

        // Ensure no transfer was made
        assertEq(tokenA.balanceOf(address(receiver)), 0);
        assertEq(tokenA.balanceOf(address(signerAccount)), tokenBalance);
    }

    function test_execute_batchedCall_twoCalls_owner_revertOnFailureFalse_succeeds() public {
        uint256 tokenBalance = tokenA.balanceOf(address(signerAccount));
        Call[] memory calls = CallUtils.initArray();
        // First call succeeds
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), tokenBalance));
        // Second call reverts
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1));
        // Set revertOnFailure to false, so the batch should succeed even if the transfer reverts
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(false);

        vm.prank(address(signerAccount));
        signerAccount.execute(batchedCall);

        // Ensure only the first transfer was made
        assertEq(tokenA.balanceOf(address(receiver)), tokenBalance);
        assertEq(tokenA.balanceOf(address(signerAccount)), 0);
    }

    function test_execute_batchedCall_unregisteredKey_revertsWithUnauthorized() public {
        TestKey memory secp256k1Key = TestKeyManager.initDefault(KeyType.Secp256k1);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        address caller = abi.decode(secp256k1Key.publicKey, (address));
        vm.prank(caller);
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(batchedCall);
    }

    function test_execute_batchedCall_nonAdmin_selfCall_reverts_withOnlyAdminCanSelfCall() public {
        TestKey memory secp256k1Key = TestKeyManager.initDefault(KeyType.Secp256k1);
        // Register key
        vm.prank(address(signerAccount));
        signerAccount.register(secp256k1Key.toKey());
        // Key is not admin, no settings

        Call[] memory calls = CallUtils.initArray();
        // Permissioned call, requires admin privilges
        TestKey memory newKey = TestKeyManager.withSeed(KeyType.Secp256k1, vm.randomUint());
        calls = calls.push(CallUtils.encodeRegisterCall(newKey));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        address caller = abi.decode(secp256k1Key.publicKey, (address));
        vm.prank(caller);
        vm.expectRevert(IKeyManagement.OnlyAdminCanSelfCall.selector);
        signerAccount.execute(batchedCall);
    }

    // Execute can contain a self call which registers a new key even if the caller is untrusted as long as the signature is valid
    function test_execute_withSignature_rootSigner_selfCall_succeeds() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        Call[] memory calls = CallUtils.initArray();
        Call memory registerCall =
            Call(address(0), 0, abi.encodeWithSelector(IKeyManagement.register.selector, p256Key.toKey()));
        calls = calls.push(registerCall);

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);

        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        signerAccount.execute(signedBatchedCall, wrappedSignature);
        assertEq(signerAccount.getKey(p256Key.toKeyHash()).hash(), p256Key.toKeyHash());
    }

    function test_execute_withSignature_P256_isAdmin_selfCall_succeeds() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        TestKey memory secp256k1Key = TestKeyManager.initDefault(KeyType.Secp256k1);

        vm.startPrank(address(signerAccount));
        signerAccount.register(p256Key.toKey());
        Settings settings = SettingsBuilder.init().fromIsAdmin(true);
        signerAccount.update(p256Key.toKeyHash(), settings);
        vm.stopPrank();

        Call[] memory calls = CallUtils.initArray();
        Call memory registerCall =
            Call(address(0), 0, abi.encodeWithSelector(IKeyManagement.register.selector, secp256k1Key.toKey()));
        calls = calls.push(registerCall);

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(DEFAULT_NONCE).withKeyHash(p256Key.toKeyHash());

        // Sign using the registered P256 key
        bytes memory signature = p256Key.sign(signerAccount.hashTypedData(signedBatchedCall.hash()));

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        assertEq(signerAccount.getKey(secp256k1Key.toKeyHash()).hash(), secp256k1Key.toKeyHash());
    }

    // Root EOA using key.hash() will revert with KeyDoesNotExist
    function test_execute_withSignature_rootEOA_withKeyHash_reverts() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 1e18)); // Transfer 1 tokenB

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        bytes32 wrongKeyHashForRootSigner = signerTestKey.toKeyHash();
        // Create hash of the calls + nonce and sign it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(wrongKeyHashForRootSigner);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());

        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        vm.expectRevert(IKeyManagement.KeyDoesNotExist.selector);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
    }

    // Root EOA must use bytes32(0) as their keyHash
    function test_execute_withSignature_rootEOA_withKeyHashZero_succeeds() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);

        bytes32 digest = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(digest);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        signerAccount.execute(signedBatchedCall, wrappedSignature);
        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_withSignature_rootEOA_singleCall_succeeds() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA

        uint256 nonceKey = 0;
        (uint256 nonce, uint64 seq) = _buildNextValidNonce(nonceKey);

        // Create hash of the calls + nonce and sign it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        signerAccount.execute(signedBatchedCall, wrappedSignature);

        // Verify the transfers succeeded
        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
        // Verify the nonce was incremented - sequence should increase by 1
        assertEq(signerAccount.getSeq(nonceKey), seq + 1);
    }

    function test_execute_withSignature_withHook_verifySignature_succeeds() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        // Signature over a wrong digest
        bytes memory signature = p256Key.sign(bytes32(0));

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(p256Key.toKeyHash());

        // Expect the signature to be invalid (because it is)
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        vm.expectRevert(ICalibur.InvalidSignature.selector);
        signerAccount.execute(signedBatchedCall, wrappedSignature);

        vm.prank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromHook(mockHook);
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        mockHook.setVerifySignatureReturnValue(true);

        // Even if the hook would successful verify the signature, it should still revert
        // because we never call hooks unless the signature is valid
        vm.expectRevert(ICalibur.InvalidSignature.selector);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
    }

    function test_execute_withSignature_withHook_beforeExecute() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        // Create hash of the calls + nonce and sign it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(p256Key.toKeyHash());
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = p256Key.sign(hashToSign);

        bytes memory revertData = bytes("revert");
        mockExecutionHook.setBeforeExecuteRevertData(revertData);
        Settings keySettings = SettingsBuilder.init().fromHook(mockExecutionHook);

        vm.prank(address(signerAccount));
        signerAccount.update(p256Key.toKeyHash(), keySettings);

        // Expect the call to revert
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        vm.expectRevert("revert");
        signerAccount.execute(signedBatchedCall, wrappedSignature);

        // Unset the hook revert
        mockExecutionHook.setBeforeExecuteRevertData(bytes(""));

        signerAccount.execute(signedBatchedCall, wrappedSignature);
        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_withSignature_revertOnFailureFalse_withHook_beforeExecute_reverts() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        // Create hash of the calls + nonce and sign it
        // Set revertOnFailure to false, but expect the hook revert to still cause the entire call to revert
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(false);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(p256Key.toKeyHash());
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = p256Key.sign(hashToSign);

        bytes memory revertData = bytes("revert");
        mockExecutionHook.setBeforeExecuteRevertData(revertData);
        Settings keySettings = SettingsBuilder.init().fromHook(mockExecutionHook);

        vm.prank(address(signerAccount));
        signerAccount.update(p256Key.toKeyHash(), keySettings);

        // Expect the call to revert
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        vm.expectRevert("revert");
        signerAccount.execute(signedBatchedCall, wrappedSignature);

        // Unset the hook revert
        mockExecutionHook.setBeforeExecuteRevertData(bytes(""));

        signerAccount.execute(signedBatchedCall, wrappedSignature);
        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_withSignature_isAdmin_checkedBeforeHook_reverts() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signerAccount));
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), SettingsBuilder.init().fromIsAdmin(false).fromHook(mockExecutionHook));
        vm.stopPrank();

        TestKey memory newKey = TestKeyManager.withSeed(KeyType.Secp256k1, vm.randomUint());

        Call[] memory calls = CallUtils.initArray();
        // Permissioned call, requires admin privilges
        calls = calls.push(CallUtils.encodeRegisterCall(newKey));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        // Create hash of the calls + nonce and sign it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(p256Key.toKeyHash());
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = p256Key.sign(hashToSign);
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        // The hook has no revertData, so it should not revert, and allow the call to succeed
        mockExecutionHook.setBeforeExecuteRevertData(bytes(""));

        vm.expectRevert(IKeyManagement.OnlyAdminCanSelfCall.selector);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
    }

    function test_execute_withSignature_invalidNonce_reverts() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 1e18)); // Transfer 1 tokenB

        // Get the current nonce components for key 0
        uint256 nonceKey = 0;
        (uint256 nonce, uint64 seq) = _buildNextValidNonce(nonceKey);

        // Create hash of the calls + nonce and sign it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);

        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory wrappedSignature = abi.encode(signerTestKey.sign(hashToSign), EMPTY_HOOK_DATA);

        // Execute the batch of calls with the signature
        signerAccount.execute(signedBatchedCall, wrappedSignature);

        // Verify the nonce was incremented - sequence should increase by 1
        assertEq(signerAccount.getSeq(nonceKey), seq + 1);

        // Try to execute again with same nonce - should revert
        vm.expectRevert(INonceManager.InvalidNonce.selector);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
    }

    function test_execute_reverts_Unauthorized_KeyDoesNotExist() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        Call[] memory calls = CallUtils.initArray();
        Call memory call =
            Call(address(signerAccount), 0, abi.encodeWithSelector(IKeyManagement.register.selector, p256Key.toKey()));
        calls = calls.push(call);

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(batchedCall);
    }

    function test_execute_reverts_Unauthorized_KeyIsNotAdmin() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        TestKey memory keyToRegister = TestKeyManager.withSeed(KeyType.Secp256k1, vm.randomUint());

        // Add a key, but the key is not an admin.
        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        Call memory call = Call(
            address(signerAccount), 0, abi.encodeWithSelector(IKeyManagement.register.selector, keyToRegister.toKey())
        );
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(batchedCall);
    }

    function test_execute_withAnyExecutor_succeeds() public {
        address random_executor = makeAddr("b0b");

        Call memory call = buildTransferCall(address(tokenA), address(receiver), 1e18);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedCall =
            CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall).withExecutor(address(0));

        bytes32 hashToSign = signerAccount.hashTypedData(signedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        vm.prank(random_executor);
        signerAccount.execute(signedCall, wrappedSignature);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_withValidExecutor_succeeds() public {
        address executor = makeAddr("executor");

        Call memory call = buildTransferCall(address(tokenA), address(receiver), 1e18);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedCall =
            CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall).withExecutor(executor);

        bytes32 hashToSign = signerAccount.hashTypedData(signedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        vm.prank(executor);
        signerAccount.execute(signedCall, wrappedSignature);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_withInvalidExecutor_revertsUnauthorized() public {
        address executor = makeAddr("executor");

        Call memory call = buildTransferCall(address(tokenA), address(receiver), 1e18);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedCall =
            CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall).withExecutor(executor);

        bytes32 hashToSign = signerAccount.hashTypedData(signedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        // Do not prank the executor, which should fail.
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(signedCall, wrappedSignature);
    }

    function test_execute_withExecutor_senderIsOwner_revertsUnauthorized() public {
        address executor = makeAddr("executor");

        Call memory call = buildTransferCall(address(tokenA), address(receiver), 1e18);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedCall =
            CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall).withExecutor(executor);

        bytes32 hashToSign = signerAccount.hashTypedData(signedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        // Even the owner on the account cannot execute the signed batched call.
        vm.startPrank(address(signerAccount));
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(signedCall, wrappedSignature);
        vm.stopPrank();
    }

    function test_execute_withAnyDeadline_succeeds() public {
        Call memory call = buildTransferCall(address(tokenA), address(receiver), 1e18);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedCall =
            CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall).withExecutor(address(0)).withDeadline(0);

        bytes32 hashToSign = signerAccount.hashTypedData(signedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        vm.warp(block.timestamp + 31536000);
        signerAccount.execute(signedCall, wrappedSignature);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_withDeadlineExact_succeeds() public {
        Call memory call = buildTransferCall(address(tokenA), address(receiver), 1e18);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withExecutor(address(0)).withDeadline(block.timestamp + 31536000);

        bytes32 hashToSign = signerAccount.hashTypedData(signedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        vm.warp(block.timestamp + 31536000);
        signerAccount.execute(signedCall, wrappedSignature);

        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
    }

    function test_execute_withDeadline_reverts() public {
        Call memory call = buildTransferCall(address(tokenA), address(receiver), 1e18);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(call);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withExecutor(address(0)).withDeadline(block.timestamp + 31535999);

        bytes32 hashToSign = signerAccount.hashTypedData(signedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        vm.warp(block.timestamp + 31536000);
        vm.expectRevert(ICalibur.SignatureExpired.selector);
        signerAccount.execute(signedCall, wrappedSignature);
    }

    /// GAS TESTS
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_reverts_withUnsupportedExecutionMode_gas() public {
        bytes32 invalid_mode = 0x0101100000000000000000000000000000000000000000000000000000000000;
        vm.prank(address(signerAccount));
        try signerAccount.execute(invalid_mode, abi.encode(CallUtils.initArray())) {}
        catch {
            vm.snapshotGasLastCall("execute_invalidMode_reverts");
        }
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_empty_gas() public {
        Call[] memory calls = CallUtils.initArray();
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        vm.prank(address(signerAccount));
        signerAccount.execute(batchedCall);
        vm.snapshotGasLastCall("execute_empty");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_single_batchedCall_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));

        bytes memory executionData = abi.encode(calls);

        vm.prank(address(signerAccount));
        signerAccount.execute(BATCHED_CALL, executionData);
        vm.snapshotGasLastCall("execute_singleCall");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_twoCalls_batchedCall_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 1e18));

        bytes memory executionData = abi.encode(calls);

        assertEq(tokenA.balanceOf(address(signerAccount)), 100e18);
        assertEq(tokenB.balanceOf(address(signerAccount)), 100e18);

        vm.prank(address(signerAccount));
        signerAccount.execute(BATCHED_CALL, executionData);
        vm.snapshotGasLastCall("execute_twoCalls");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_native_single_batchedCall_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(0), address(receiver), 1e18));

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        vm.prank(address(signerAccount));
        signerAccount.execute(batchedCall);
        vm.snapshotGasLastCall("execute_native_singleCall");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_single_batchedCall_withSignature_rootSigner_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        vm.snapshotGasLastCall("execute_withSignature_singleCall");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_signedBatchedCall_rootSigner_executor_gas() public {
        address executor = makeAddr("executor");

        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH).withExecutor(executor);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        vm.prank(executor);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        vm.snapshotGasLastCall("execute_withSignature_executor_singleCall");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_single_batchedCall_withSignature_P256_gas() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));

        vm.prank(address(signer));
        signerAccount.register(p256Key.toKey());

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(DEFAULT_NONCE).withKeyHash(p256Key.toKeyHash());

        bytes memory signature = p256Key.sign(signerAccount.hashTypedData(signedBatchedCall.hash()));

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        vm.snapshotGasLastCall("execute_withSignature_P256_singleCall");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_twoCalls_batchedCall_withSignature_rootSigner_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 1e18));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        vm.snapshotGasLastCall("execute_withSignature_twoCalls");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_native_single_batchedCall_withSignature_eoaSigner_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(0), address(receiver), 1e18));

        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        vm.snapshotGasLastCall("execute_withSignature_singleCall_native");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_withSignature_singleCall_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA

        // Get the current nonce components for key 0
        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        // Create hash of the calls + nonce and sign it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(hashToSign);

        // Execute the batch of calls with the signature
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        vm.snapshotGasLastCall("execute_withSignature_singleCall");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_execute_withSignature_twoCalls_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA
        calls = calls.push(buildTransferCall(address(tokenB), address(receiver), 1e18)); // Transfer 1 tokenB

        // Get the current nonce components for key 0
        uint256 nonceKey = 0;
        (uint256 nonce,) = _buildNextValidNonce(nonceKey);

        // Create hash of the calls + nonce and sign it
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 hashToSign = signerAccount.hashTypedData(signedBatchedCall.hash());

        bytes memory signature = signerTestKey.sign(hashToSign);

        // Execute the batch of calls with the signature
        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);

        signerAccount.execute(signedBatchedCall, wrappedSignature);
        vm.snapshotGasLastCall("execute_withSignature_twoCalls");
    }

    /**
     * Edge case tests
     */
    function test_execute_batch_emptyCalls_succeeds() public {
        Call[] memory calls = CallUtils.initArray();
        vm.prank(address(signerAccount));
        signerAccount.execute(BATCHED_CALL, abi.encode(calls));
    }

    function test_execute_batch_emptyCalls_revertsWhenUnauthorized() public {
        Call[] memory calls = CallUtils.initArray();
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(BATCHED_CALL, abi.encode(calls));
    }

    /**
     * Self call tests
     */
    function test_execute_register_update_asRoot_succeeds() public {
        TestKey memory newKey = TestKeyManager.initDefault(KeyType.Secp256k1);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(CallUtils.encodeRegisterCall(newKey));
        calls = calls.push(CallUtils.encodeUpdateCall(newKey.toKeyHash(), Settings.wrap(0)));

        vm.prank(address(signerAccount));
        signerAccount.execute(BATCHED_CALL, abi.encode(calls));
    }

    function test_execute_register_update_asNonRoot_reverts() public {
        TestKey memory newKey = TestKeyManager.initDefault(KeyType.Secp256k1);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(CallUtils.encodeRegisterCall(newKey));
        calls = calls.push(CallUtils.encodeUpdateCall(newKey.toKeyHash(), Settings.wrap(0)));

        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.execute(BATCHED_CALL, abi.encode(calls));
    }

    function test_execute_register_update_withRootSignature_succeeds() public {
        // Generate a test key to register
        TestKey memory newKey = TestKeyManager.initDefault(KeyType.Secp256k1);
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(CallUtils.encodeRegisterCall(newKey));
        calls = calls.push(CallUtils.encodeUpdateCall(newKey.toKeyHash(), Settings.wrap(0)));

        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(DEFAULT_NONCE).withKeyHash(KeyLib.ROOT_KEY_HASH);

        bytes32 digest = signerAccount.hashTypedData(signedBatchedCall.hash());
        bytes memory signature = signerTestKey.sign(digest);

        bytes memory wrappedSignature = abi.encode(signature, EMPTY_HOOK_DATA);
        signerAccount.execute(signedBatchedCall, wrappedSignature);
        assertEq(Settings.unwrap(signerAccount.getKeySettings(newKey.toKeyHash())), 0);
    }

    function test_multicall_succeeds() public {
        // Create two separate batches of calls
        Call[] memory calls1 = CallUtils.initArray();
        Call[] memory calls2 = CallUtils.initArray();

        calls1 = calls1.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA
        calls2 = calls2.push(buildTransferCall(address(tokenB), address(receiver), 1e18)); // Transfer 1 tokenB

        TestKey memory p256Key1 = TestKeyManager.initDefault(KeyType.P256);
        TestKey memory p256Key2 = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signer));
        signerAccount.register(p256Key1.toKey());
        signerAccount.register(p256Key2.toKey());
        vm.stopPrank();

        // Create signed calls for each batch
        BatchedCall memory batchedCall1 = CallUtils.initBatchedCall().withCalls(calls1).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall1 = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall1)
            .withNonce(DEFAULT_NONCE).withKeyHash(p256Key1.toKeyHash());
        bytes memory signature1 = p256Key1.sign(signerAccount.hashTypedData(signedBatchedCall1.hash()));
        bytes memory wrappedSignature1 = abi.encode(signature1, EMPTY_HOOK_DATA);

        BatchedCall memory batchedCall2 = CallUtils.initBatchedCall().withCalls(calls2).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall2 = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall2)
            .withNonce(DEFAULT_NONCE + 1).withKeyHash(p256Key2.toKeyHash());
        bytes memory signature2 = p256Key2.sign(signerAccount.hashTypedData(signedBatchedCall2.hash()));
        bytes memory wrappedSignature2 = abi.encode(signature2, EMPTY_HOOK_DATA);

        // Create multicall data
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = CallUtils.encodeSignedExecuteCall(signedBatchedCall1, wrappedSignature1);
        multicallData[1] = CallUtils.encodeSignedExecuteCall(signedBatchedCall2, wrappedSignature2);

        // Execute the multicall
        vm.prank(address(signerAccount));
        signerAccount.multicall(multicallData);

        // Verify the results
        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
        assertEq(tokenB.balanceOf(address(receiver)), 1e18);
    }

    function test_multicall_rootKey_succeeds() public {
        // Create two separate batches of calls
        Call[] memory calls1 = CallUtils.initArray();
        Call[] memory calls2 = CallUtils.initArray();

        calls1 = calls1.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA
        calls2 = calls2.push(buildTransferCall(address(tokenB), address(receiver), 1e18)); // Transfer 1 tokenB

        BatchedCall memory batchedCall1 = CallUtils.initBatchedCall().withCalls(calls1).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall1 = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall1)
            .withNonce(DEFAULT_NONCE).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 digest1 = signerAccount.hashTypedData(signedBatchedCall1.hash());
        bytes memory signature1 = signerTestKey.sign(digest1);
        bytes memory wrappedSignature1 = abi.encode(signature1, EMPTY_HOOK_DATA);

        BatchedCall memory batchedCall2 = CallUtils.initBatchedCall().withCalls(calls2).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall2 = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall2)
            .withNonce(DEFAULT_NONCE + 1).withKeyHash(KeyLib.ROOT_KEY_HASH);
        bytes32 digest2 = signerAccount.hashTypedData(signedBatchedCall2.hash());
        bytes memory signature2 = signerTestKey.sign(digest2);
        bytes memory wrappedSignature2 = abi.encode(signature2, EMPTY_HOOK_DATA);

        // Build the mixed multicall data array with two different types of execute calls
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = CallUtils.encodeSignedExecuteCall(signedBatchedCall1, wrappedSignature1);
        multicallData[1] = CallUtils.encodeSignedExecuteCall(signedBatchedCall2, wrappedSignature2);

        signerAccount.multicall(multicallData);

        // Verify the results
        assertEq(tokenA.balanceOf(address(receiver)), 1e18);
        assertEq(tokenB.balanceOf(address(receiver)), 1e18);
    }

    function test_multicall_revertsWhenUnauthorized() public {
        // Create two separate batches of calls
        Call[] memory calls1 = CallUtils.initArray();
        Call[] memory calls2 = CallUtils.initArray();

        calls1 = calls1.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA
        calls2 = calls2.push(buildTransferCall(address(tokenB), address(receiver), 1e18)); // Transfer 1 tokenB

        TestKey memory p256Key1 = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signer));
        signerAccount.register(p256Key1.toKey());
        vm.stopPrank();

        BatchedCall memory batchedCall1 = CallUtils.initBatchedCall().withCalls(calls1).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall1 = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall1)
            .withNonce(DEFAULT_NONCE).withKeyHash(p256Key1.toKeyHash());
        bytes memory signature1 = p256Key1.sign(signerAccount.hashTypedData(signedBatchedCall1.hash()));
        bytes memory wrappedSignature1 = abi.encode(signature1, EMPTY_HOOK_DATA);

        BatchedCall memory batchedCall2 = CallUtils.initBatchedCall().withCalls(calls2).withRevertOnFailure(true);

        // Build the mixed multicall data array with two different types of execute calls
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = CallUtils.encodeSignedExecuteCall(signedBatchedCall1, wrappedSignature1);
        // this call is not signed and caller is not authorized
        multicallData[1] = CallUtils.encodeBatchedExecuteCall(batchedCall2);

        // The call should revert since we're not authorized to make the second call
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.multicall(multicallData);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_multicall_gas() public {
        // Create two separate batches of calls
        Call[] memory calls1 = CallUtils.initArray();
        Call[] memory calls2 = CallUtils.initArray();

        calls1 = calls1.push(buildTransferCall(address(tokenA), address(receiver), 1e18)); // Transfer 1 tokenA
        calls2 = calls2.push(buildTransferCall(address(tokenB), address(receiver), 1e18)); // Transfer 1 tokenB

        TestKey memory p256Key1 = TestKeyManager.initDefault(KeyType.P256);
        TestKey memory p256Key2 = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signer));
        signerAccount.register(p256Key1.toKey());
        signerAccount.register(p256Key2.toKey());
        vm.stopPrank();

        // Create signed calls for each batch
        BatchedCall memory batchedCall1 = CallUtils.initBatchedCall().withCalls(calls1).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall1 = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall1)
            .withNonce(DEFAULT_NONCE).withKeyHash(p256Key1.toKeyHash());
        bytes memory signature1 = p256Key1.sign(signerAccount.hashTypedData(signedBatchedCall1.hash()));
        bytes memory wrappedSignature1 = abi.encode(signature1, EMPTY_HOOK_DATA);
        BatchedCall memory batchedCall2 = CallUtils.initBatchedCall().withCalls(calls2).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall2 = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall2)
            .withNonce(DEFAULT_NONCE + 1).withKeyHash(p256Key2.toKeyHash());
        bytes memory signature2 = p256Key2.sign(signerAccount.hashTypedData(signedBatchedCall2.hash()));
        bytes memory wrappedSignature2 = abi.encode(signature2, EMPTY_HOOK_DATA);

        // Create multicall data using the new utility function
        SignedBatchedCall[] memory signedBatchedCalls = new SignedBatchedCall[](2);
        signedBatchedCalls[0] = signedBatchedCall1;
        signedBatchedCalls[1] = signedBatchedCall2;

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;

        // Create multicall data
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] = CallUtils.encodeSignedExecuteCall(signedBatchedCall1, wrappedSignature1);
        multicallData[1] = CallUtils.encodeSignedExecuteCall(signedBatchedCall2, wrappedSignature2);

        // Execute the multicall
        vm.prank(address(signerAccount));
        signerAccount.multicall(multicallData);
        vm.snapshotGasLastCall("multicall");
    }
}
