// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {DelegationHandler} from "../../utils/DelegationHandler.sol";
import {HookHandler} from "../../utils/HookHandler.sol";
import {MultiSignerValidatorHook} from "../../../src/hooks/example/MultiSignerValidatorHook.sol";
import {TestKey, TestKeyManager} from "../../utils/TestKeyManager.sol";
import {Key, KeyType, KeyLib} from "../../../src/libraries/KeyLib.sol";
import {IHook} from "../../../src/interfaces/IHook.sol";

contract MultiSignerValidationHookTest is DelegationHandler, HookHandler {
    using TestKeyManager for TestKey;

    MultiSignerValidatorHook internal hook;
    TestKey internal baseKey;

    event RequiredSignerAdded(bytes32 keyHash, bytes32 signerKeyHash);

    error SignerNotRegistered();

    function setUp() public {
        setUpDelegation();
        setUpHooks();

        hook = new MultiSignerValidatorHook();

        baseKey = TestKeyManager.initDefault(KeyType.Secp256k1);

        // Add a signer on signerAccount
        vm.prank(address(signerAccount));
        signerAccount.register(baseKey.toKey());
    }

    /// Add a required signer for signerAccount
    function _addRequiredSigner(TestKey memory key) internal {
        bytes memory encodedKey = abi.encode(key);

        bytes32 accountKeyHash = baseKey.toKeyHash();
        bytes32 signerKeyHash = key.toKeyHash();

        vm.expectEmit();
        emit RequiredSignerAdded(accountKeyHash, signerKeyHash);

        vm.prank(address(signerAccount));
        hook.addRequiredSigner(accountKeyHash, encodedKey);
    }

    function test_addRequiredSigner_succeeds() public {
        TestKey memory key = TestKeyManager.initDefault(KeyType.P256);
        _addRequiredSigner(key);
    }

    function test_verifySignature_withRequiredSignatures_returnsTrue() public {
        TestKey memory key = TestKeyManager.initDefault(KeyType.P256);
        _addRequiredSigner(key);

        bytes32 digest = keccak256("digest");
        bytes memory signature = key.sign(digest);
        bytes[] memory wrappedSignerSignatures = new bytes[](1);
        wrappedSignerSignatures[0] = abi.encode(key.toKeyHash(), signature);

        bytes memory hookData = abi.encode(wrappedSignerSignatures);

        // Prank as signerAccount because hooks are called from signerAccount
        vm.prank(address(signerAccount));
        (bytes4 selector, bool isValid) = hook.overrideVerifySignature(baseKey.toKeyHash(), digest, hookData);
        assertEq(selector, IHook.overrideVerifySignature.selector);
        assertEq(isValid, true);
    }

    function test_verifySignature_reverts_withSignerNotRegistered() public {
        TestKey memory key = TestKeyManager.initDefault(KeyType.P256);
        _addRequiredSigner(key);

        bytes32 digest = keccak256("digest");
        bytes[] memory wrappedSignerSignatures = new bytes[](1);
        // signer is different than required signer
        wrappedSignerSignatures[0] = abi.encode(bytes32(0), bytes(""));

        bytes memory hookData = abi.encode(wrappedSignerSignatures);

        vm.expectRevert(SignerNotRegistered.selector);
        vm.prank(address(signerAccount));
        hook.overrideVerifySignature(baseKey.toKeyHash(), digest, hookData);
    }

    function test_verifySignature_withInvalidSignatures_returnsFalse() public {
        TestKey memory key = TestKeyManager.initDefault(KeyType.P256);
        _addRequiredSigner(key);

        bytes32 digest = keccak256("digest");
        bytes memory invalidSignature = key.sign(keccak256("invalid"));

        bytes[] memory wrappedSignerSignatures = new bytes[](1);
        wrappedSignerSignatures[0] = abi.encode(key.toKeyHash(), invalidSignature);

        bytes memory hookData = abi.encode(wrappedSignerSignatures);

        vm.prank(address(signerAccount));
        (bytes4 selector, bool isValid) = hook.overrideVerifySignature(baseKey.toKeyHash(), digest, hookData);
        assertEq(selector, IHook.overrideVerifySignature.selector);
        assertEq(isValid, false);
    }
}
