// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TokenHandler} from "./utils/TokenHandler.sol";
import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {HookHandler} from "./utils/HookHandler.sol";
import {ExecuteFixtures} from "./utils/ExecuteFixtures.sol";
import {IERC7821} from "../src/interfaces/IERC7821.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IERC4337Account} from "../src/ERC4337Account.sol";
import {UserOpBuilder} from "./utils/UserOpBuilder.sol";
import {HandlerCall, CallUtils} from "./utils/CallUtils.sol";
import {Call} from "../src/libraries/CallLib.sol";
import {TestKeyManager, TestKey} from "./utils/TestKeyManager.sol";
import {KeyType} from "../src/libraries/KeyLib.sol";
import {IAccountExecute} from "account-abstraction/interfaces/IAccountExecute.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IKeyManagement} from "../src/interfaces/IKeyManagement.sol";
import {KeyLib} from "../src/libraries/KeyLib.sol";
import {INonceManager} from "../src/interfaces/INonceManager.sol";
import {BatchedCall} from "../src/libraries/BatchedCallLib.sol";
import {SettingsBuilder} from "./utils/SettingsBuilder.sol";
import {Settings} from "../src/libraries/SettingsLib.sol";

contract Calibur4337Test is ExecuteFixtures, DelegationHandler, TokenHandler, HookHandler {
    using CallUtils for *;
    using UserOpBuilder for PackedUserOperation;
    using TestKeyManager for TestKey;
    using SettingsBuilder for Settings;

    address receiver = makeAddr("receiver");
    address payable bundler = payable(makeAddr("bundler"));

    function setUp() public {
        setUpDelegation();
        setUpTokens();
        setUpHooks();

        vm.deal(address(signerAccount), 100e18);
        tokenA.mint(address(signerAccount), 100e18);
        tokenB.mint(address(signerAccount), 100e18);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_handleOps_single_eoaSigner_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        bytes memory callData = abi.encodeWithSelector(IAccountExecute.executeUserOp.selector, batchedCall);

        PackedUserOperation memory userOp =
            UserOpBuilder.initDefault().withSender(address(signerAccount)).withNonce(0).withCallData(callData);

        bytes32 digest = entryPoint.getUserOpHash(userOp);
        userOp.withSignature(abi.encode(KeyLib.ROOT_KEY_HASH, signerTestKey.sign(digest), EMPTY_HOOK_DATA));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        uint256 tokenBalanceBefore = tokenA.balanceOf(address(receiver));

        entryPoint.handleOps(userOps, bundler);
        vm.snapshotGasLastCall("hanldeOps_BATCHED_CALL_singleCall_eoaSigner");

        uint256 tokenBalanceAfter = tokenA.balanceOf(address(receiver));
        assertEq(tokenBalanceAfter, tokenBalanceBefore + 1e18);
    }

    // Test that the root key can pass a raw ecdsa signature into userOp.signature
    function test_handleOps_single_eoaSigner_rawSignature_gas() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        bytes memory callData = abi.encodeWithSelector(IAccountExecute.executeUserOp.selector, batchedCall);

        PackedUserOperation memory userOp =
            UserOpBuilder.initDefault().withSender(address(signerAccount)).withNonce(0).withCallData(callData);

        bytes32 digest = entryPoint.getUserOpHash(userOp);
        userOp.withSignature(signerTestKey.sign(digest));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        uint256 tokenBalanceBefore = tokenA.balanceOf(address(receiver));

        entryPoint.handleOps(userOps, bundler);

        uint256 tokenBalanceAfter = tokenA.balanceOf(address(receiver));
        assertEq(tokenBalanceAfter, tokenBalanceBefore + 1e18);
    }

    // Show that a non root key cannot pass a raw ecdsa signature into userOp.signature
    function test_handleOps_single_nonRootKey_rawSignature_reverts() public {
        TestKey memory secp256k1Key = TestKeyManager.initDefault(KeyType.Secp256k1);
        // Make the key an admin key
        Settings settings = SettingsBuilder.init().fromIsAdmin(true);
        vm.prank(address(signerAccount));
        signerAccount.register(secp256k1Key.toKey());
        vm.prank(address(signerAccount));
        signerAccount.update(secp256k1Key.toKeyHash(), settings);

        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        bytes memory callData = abi.encodeWithSelector(IAccountExecute.executeUserOp.selector, batchedCall);

        PackedUserOperation memory userOp =
            UserOpBuilder.initDefault().withSender(address(signerAccount)).withNonce(0).withCallData(callData);

        bytes32 digest = entryPoint.getUserOpHash(userOp);
        // Sign but don't wrap with the keyHash and hookData
        userOp.withSignature(secp256k1Key.sign(digest));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // Expect revert in validateUserOp
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedOp.selector, 0, "AA24 signature error"));
        entryPoint.handleOps(userOps, bundler);
    }

    // A UserOperation with empty initCode is rejected: without the EIP-7702 marker the EntryPoint
    // does not bind userOpHash to the active delegate, so such ops could replay after a delegate change.
    function test_handleOps_emptyInitCode_reverts() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        bytes memory callData = abi.encodeWithSelector(IAccountExecute.executeUserOp.selector, batchedCall);

        PackedUserOperation memory userOp = UserOpBuilder.initDefault().withSender(address(signerAccount)).withNonce(0)
            .withCallData(callData).withInitCode("");

        bytes32 digest = entryPoint.getUserOpHash(userOp);
        userOp.withSignature(abi.encode(KeyLib.ROOT_KEY_HASH, signerTestKey.sign(digest), EMPTY_HOOK_DATA));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedOpWithRevert.selector,
                0,
                "AA23 reverted",
                abi.encodeWithSelector(IERC4337Account.InvalidUserOpInitCode.selector)
            )
        );
        entryPoint.handleOps(userOps, bundler);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_handleOps_single_P256_gas() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        /// This is extremely jank, but we have to encode the calls with the executeUserOp selector so the 4337 entrypoint forces a call to executeUserOp on the account.
        bytes memory callData = abi.encodeWithSelector(IAccountExecute.executeUserOp.selector, batchedCall);

        PackedUserOperation memory userOp =
            UserOpBuilder.initDefault().withSender(address(signerAccount)).withNonce(0).withCallData(callData);

        bytes32 digest = entryPoint.getUserOpHash(userOp);
        userOp.withSignature(abi.encode(p256Key.toKeyHash(), p256Key.sign(digest), EMPTY_HOOK_DATA));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        uint256 tokenBalanceBefore = tokenA.balanceOf(address(receiver));

        entryPoint.handleOps(userOps, bundler);
        vm.snapshotGasLastCall("hanldeOps_BATCHED_CALL_singleCall_P256");

        uint256 tokenBalanceAfter = tokenA.balanceOf(address(receiver));
        assertEq(tokenBalanceAfter, tokenBalanceBefore + 1e18);
    }

    // A non-admin key cannot drain the account's EntryPoint deposit through the executeUserOp path.
    // The signature is valid so validateUserOp passes, but the EntryPoint call reverts during execution
    // and the EntryPoint surfaces it via UserOperationRevertReason.
    function test_handleOps_nonAdmin_entryPointCall_reverts_withOnlyAdminCanCallEntryPoint() public {
        TestKey memory secp256k1Key = TestKeyManager.initDefault(KeyType.Secp256k1);
        // Register key; key is not admin, no settings
        vm.prank(address(signerAccount));
        signerAccount.register(secp256k1Key.toKey());

        // Seed an EntryPoint deposit that the attacker would attempt to drain
        entryPoint.depositTo{value: 1e18}(address(signerAccount));
        uint256 depositBefore = entryPoint.balanceOf(address(signerAccount));

        Call[] memory calls = CallUtils.initArray();
        // withdrawTo would drain the account's EntryPoint deposit as a zero-value call
        calls = calls.push(
            Call(
                address(entryPoint), 0, abi.encodeWithSelector(entryPoint.withdrawTo.selector, receiver, depositBefore)
            )
        );
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);

        bytes memory callData = abi.encodeWithSelector(IAccountExecute.executeUserOp.selector, batchedCall);

        PackedUserOperation memory userOp =
            UserOpBuilder.initDefault().withSender(address(signerAccount)).withNonce(0).withCallData(callData);

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        userOp.withSignature(abi.encode(secp256k1Key.toKeyHash(), secp256k1Key.sign(userOpHash), EMPTY_HOOK_DATA));

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        // The EntryPoint catches the execution-phase revert and surfaces it via UserOperationRevertReason
        vm.expectEmit(true, true, true, true, address(entryPoint));
        emit IEntryPoint.UserOperationRevertReason(
            userOpHash,
            address(signerAccount),
            0,
            abi.encodeWithSelector(IKeyManagement.OnlyAdminCanCallEntryPoint.selector)
        );
        entryPoint.handleOps(userOps, bundler);

        // The malicious withdrawal never executed, so the attacker's receiver got nothing.
        // (The account's own deposit only decreases by the bundler gas reimbursement.)
        assertEq(receiver.balance, 0);
    }
}
