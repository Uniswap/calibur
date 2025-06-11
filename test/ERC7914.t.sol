// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {IERC7914} from "../src/interfaces/IERC7914.sol";
import {ERC7914} from "../src/ERC7914.sol";
import {BaseAuthorization} from "../src/BaseAuthorization.sol";
import {IPermit2} from "../lib/permit2/src/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "../lib/permit2/src/interfaces/ISignatureTransfer.sol";
import {ERC20ETH} from "../lib/erc20-eth/src/ERC20Eth.sol";
import {IAllowanceTransfer} from "../lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {Permit2Utils} from "./utils/Permit2Utils.sol";
import {TestKeyManager, TestKey} from "./utils/TestKeyManager.sol";
import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {TypedDataSignBuilder} from "./utils/TypedDataSignBuilder.sol";
import {KeyType} from "../src/libraries/KeyLib.sol";
import {FFISignTypedData} from "./utils/FFISignTypedData.sol";
import {ERC1271Handler} from "./utils/ERC1271Handler.sol";
import {PermitSingle, PermitDetails} from "./utils/MockERC1271VerifyingContract.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ERC7914Test is DelegationHandler, ERC1271Handler, FFISignTypedData {
    using Permit2Utils for *;
    using TestKeyManager for TestKey;

    event TransferFromNative(address indexed from, address indexed to, uint256 value);
    event ApproveNative(address indexed owner, address indexed spender, uint256 value);
    event ApproveNativeTransient(address indexed owner, address indexed spender, uint256 value);
    event TransferFromNativeTransient(address indexed from, address indexed to, uint256 value);
    event NativeAllowanceUpdated(address indexed spender, uint256 value);

    address bob = makeAddr("bob");
    address recipient = makeAddr("recipient");

    struct Permit2TestSetup {
        ERC20ETH erc20Eth;
        IPermit2 permit2;
        uint256 spendAmount;
        uint256 totalAmount;
    }

    function _setupPermit2Test() internal returns (Permit2TestSetup memory setup) {
        setup.erc20Eth = new ERC20ETH();
        setup.permit2 = IPermit2(Permit2Utils.deployPermit2());
        setup.spendAmount = 1 ether;
        setup.totalAmount = 2 ether;
        
        vm.deal(address(signerAccount), setup.totalAmount);
        vm.prank(address(signerAccount));
        signerAccount.approveNative(address(setup.erc20Eth), type(uint256).max);
    }

    function _createPermit(address token, uint256 amount) internal view returns (ISignatureTransfer.PermitTransferFrom memory) {
        return ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: token,
                amount: amount
            }),
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });
    }

    function _testPermit2Transfer(
        IPermit2 permit2,
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes memory sig,
        uint256 spendAmount,
        uint256 totalAmount,
        bool isWitness,
        bytes32 witness,
        string memory witnessTypeString
    ) internal {
        // Test invalid transfer (too much)
        ISignatureTransfer.SignatureTransferDetails memory invalidTransfer = 
            ISignatureTransfer.SignatureTransferDetails({
                to: bob,
                requestedAmount: spendAmount + 1
            });

        vm.expectRevert(abi.encodeWithSelector(ISignatureTransfer.InvalidAmount.selector, spendAmount));
        vm.prank(bob);
        if (isWitness) {
            permit2.permitWitnessTransferFrom(permit, invalidTransfer, address(signerAccount), witness, witnessTypeString, sig);
        } else {
            permit2.permitTransferFrom(permit, invalidTransfer, address(signerAccount), sig);
        }

        // Test valid transfer
        ISignatureTransfer.SignatureTransferDetails memory validTransfer = 
            ISignatureTransfer.SignatureTransferDetails({
                to: bob,
                requestedAmount: spendAmount
            });
        
        vm.prank(bob);
        if (isWitness) {
            permit2.permitWitnessTransferFrom(permit, validTransfer, address(signerAccount), witness, witnessTypeString, sig);
        } else {
            permit2.permitTransferFrom(permit, validTransfer, address(signerAccount), sig);
        }

        // Verify the transfer
        assertEq(bob.balance, spendAmount);
        assertEq(address(signerAccount).balance, totalAmount - spendAmount);
    }

    function setUp() public {
        setUpDelegation();
    }

    function test_approveNative_revertsWithUnauthorized() public {
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.approveNative(bob, 1 ether);
    }

    function test_approveNative_succeeds() public {
        vm.expectEmit(true, true, false, true);
        emit ApproveNative(address(signerAccount), bob, 1 ether);
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNative(bob, 1 ether);
        assertTrue(success);
        assertEq(signerAccount.nativeAllowance(bob), 1 ether);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_approveNative_gas() public {
        vm.expectEmit(true, true, false, true);
        emit ApproveNative(address(signerAccount), bob, 1 ether);
        vm.startPrank(address(signerAccount));
        signerAccount.approveNative(bob, 1 ether);
        vm.snapshotGasLastCall("approveNative");
    }

    function test_transferFromNative_revertsWithIncorrectSender() public {
        vm.expectRevert(IERC7914.IncorrectSender.selector);
        signerAccount.transferFromNative(bob, recipient, 1 ether);
    }

    function test_transferFromNative_revertsWithAllowanceExceeded() public {
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNative(bob, 1 ether);
        assertTrue(success);
        vm.prank(bob);
        vm.expectRevert(IERC7914.AllowanceExceeded.selector);
        signerAccount.transferFromNative(address(signerAccount), bob, 2 ether);
    }

    function test_transferFromNative_zeroAmount_returnsTrue() public {
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNative(bob, 1 ether);
        vm.prank(bob);
        success = signerAccount.transferFromNative(address(signerAccount), bob, 0);
        assertEq(success, true);
    }

    function test_transferFromNative_succeeds() public {
        // send eth to signerAccount
        vm.deal(address(signerAccount), 1 ether);
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNative(bob, 1 ether);
        assertTrue(success);
        uint256 bobBalanceBefore = bob.balance;
        uint256 signerAccountBalanceBefore = address(signerAccount).balance;
        vm.expectEmit(true, true, false, true);
        emit NativeAllowanceUpdated(bob, 0 ether);
        vm.expectEmit(true, true, false, true);
        emit TransferFromNative(address(signerAccount), bob, 1 ether);
        vm.prank(bob);
        success = signerAccount.transferFromNative(address(signerAccount), bob, 1 ether);
        assertTrue(success);
        assertEq(signerAccount.nativeAllowance(bob), 0);
        assertEq(bob.balance, bobBalanceBefore + 1 ether);
        assertEq(address(signerAccount).balance, signerAccountBalanceBefore - 1 ether);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_transferFromNative_gas() public {
        // send eth to signerAccount
        vm.deal(address(signerAccount), 1 ether);
        vm.prank(address(signerAccount));
        signerAccount.approveNative(bob, 1 ether);
        vm.expectEmit(true, true, false, true);
        emit TransferFromNative(address(signerAccount), bob, 1 ether);
        vm.prank(bob);
        signerAccount.transferFromNative(address(signerAccount), bob, 1 ether);
        vm.snapshotGasLastCall("transferFromNative");
    }

    function test_fuzz_transferFromNative(uint256 balance, uint256 approvedAmount, uint256 transferAmount) public {
        // ensure there are funds in the signerAccount
        vm.deal(address(signerAccount), balance);
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNative(bob, approvedAmount);
        assertEq(signerAccount.nativeAllowance(bob), approvedAmount);
        assertTrue(success);

        uint256 bobBalanceBefore = bob.balance;
        uint256 signerAccountBalanceBefore = address(signerAccount).balance;

        vm.prank(bob);
        // Check if the transfer amount is greater than the approved amount or the balance of the signerAccount
        // and expect the appropriate revert
        if (transferAmount > approvedAmount) {
            vm.expectRevert(IERC7914.AllowanceExceeded.selector);
        } else if (transferAmount > address(signerAccount).balance) {
            vm.expectRevert(IERC7914.TransferNativeFailed.selector);
        }
        success = signerAccount.transferFromNative(address(signerAccount), bob, transferAmount);
        // if the transfer was successful, check the balances have updated
        // otherwise check the balances have not changed
        if (success) {
            if (approvedAmount < type(uint256).max) {
                assertEq(signerAccount.nativeAllowance(bob), approvedAmount - transferAmount);
            } else {
                assertEq(signerAccount.nativeAllowance(bob), approvedAmount);
            }
            assertEq(bob.balance, bobBalanceBefore + transferAmount);
            assertEq(address(signerAccount).balance, signerAccountBalanceBefore - transferAmount);
        } else {
            assertEq(signerAccount.nativeAllowance(bob), approvedAmount);
            assertEq(bob.balance, bobBalanceBefore);
            assertEq(address(signerAccount).balance, signerAccountBalanceBefore);
        }
    }

    function test_approveNativeTransient_revertsWithUnauthorized() public {
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.approveNativeTransient(bob, 1 ether);
    }

    function test_approveNativeTransient_succeeds() public {
        vm.expectEmit(true, true, false, true);
        emit ApproveNativeTransient(address(signerAccount), bob, 1 ether);
        vm.startPrank(address(signerAccount));
        bool success = signerAccount.approveNativeTransient(bob, 1 ether);
        assertTrue(success);
        assertEq(signerAccount.transientNativeAllowance(bob), 1 ether);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_approveNativeTransient_gas() public {
        vm.expectEmit(true, true, false, true);
        emit ApproveNativeTransient(address(signerAccount), bob, 1 ether);
        vm.startPrank(address(signerAccount));
        signerAccount.approveNativeTransient(bob, 1 ether);
        vm.snapshotGasLastCall("approveNativeTransient");
    }

    function test_transferFromNativeTransient_revertsWithIncorrectSender() public {
        vm.expectRevert(IERC7914.IncorrectSender.selector);
        signerAccount.transferFromNativeTransient(bob, recipient, 1 ether);
    }

    function test_transferFromNativeTransient_revertsWithAllowanceExceeded() public {
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNativeTransient(bob, 1 ether);
        assertTrue(success);
        vm.prank(bob);
        vm.expectRevert(IERC7914.AllowanceExceeded.selector);
        signerAccount.transferFromNativeTransient(address(signerAccount), bob, 2 ether);
    }

    function test_transferFromNativeTransient_zeroAmount_returnsTrue() public {
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNativeTransient(bob, 1 ether);
        assertTrue(success);
        success = signerAccount.transferFromNativeTransient(address(signerAccount), bob, 0);
        assertEq(success, true);
    }

    function test_transferFromNativeTransient_succeeds() public {
        // send eth to signerAccount
        vm.deal(address(signerAccount), 1 ether);

        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNativeTransient(bob, 1 ether);
        assertTrue(success);

        uint256 bobBalanceBefore = bob.balance;
        uint256 signerAccountBalanceBefore = address(signerAccount).balance;

        vm.expectEmit(true, true, false, true);
        emit TransferFromNativeTransient(address(signerAccount), bob, 1 ether);

        vm.prank(bob);
        success = signerAccount.transferFromNativeTransient(address(signerAccount), bob, 1 ether);
        assertTrue(success);

        assertEq(signerAccount.transientNativeAllowance(bob), 0);
        assertEq(bob.balance, bobBalanceBefore + 1 ether);
        assertEq(address(signerAccount).balance, signerAccountBalanceBefore - 1 ether);
    }

    function test_fuzz_transferFromNativeTransient_succeeds(
        uint256 balance,
        uint256 approvedAmount,
        uint256 transferAmount
    ) public {
        // ensure there are funds in the signerAccount
        vm.deal(address(signerAccount), balance);
        vm.prank(address(signerAccount));
        bool success = signerAccount.approveNativeTransient(bob, approvedAmount);
        assertEq(signerAccount.transientNativeAllowance(bob), approvedAmount);
        assertTrue(success);

        uint256 bobBalanceBefore = bob.balance;
        uint256 signerAccountBalanceBefore = address(signerAccount).balance;

        vm.prank(bob);
        // Check if the transfer amount is greater than the approved amount or the balance of the signerAccount
        // and expect the appropriate revert
        if (transferAmount > approvedAmount) {
            vm.expectRevert(IERC7914.AllowanceExceeded.selector);
        } else if (transferAmount > address(signerAccount).balance) {
            vm.expectRevert(IERC7914.TransferNativeFailed.selector);
        }
        success = signerAccount.transferFromNativeTransient(address(signerAccount), bob, transferAmount);
        // if the transfer was successful, check the balances have updated
        // otherwise check the balances have not changed
        if (success) {
            if (approvedAmount < type(uint256).max) {
                assertEq(signerAccount.transientNativeAllowance(bob), approvedAmount - transferAmount);
            } else {
                assertEq(signerAccount.transientNativeAllowance(bob), approvedAmount);
            }
            assertEq(bob.balance, bobBalanceBefore + transferAmount);
            assertEq(address(signerAccount).balance, signerAccountBalanceBefore - transferAmount);
        } else {
            assertEq(signerAccount.transientNativeAllowance(bob), approvedAmount);
            assertEq(bob.balance, bobBalanceBefore);
            assertEq(address(signerAccount).balance, signerAccountBalanceBefore);
        }
    }

    // Test that a permit2 signature can be used to transfer native ETH
    // using the ERC20-eth contract
    function test_permit2SignatureTransferNative() public {
        Permit2TestSetup memory setup = _setupPermit2Test();
        ISignatureTransfer.PermitTransferFrom memory permit = _createPermit(address(setup.erc20Eth), setup.spendAmount);

        bytes memory sig;
        {        
            (bytes32 appDomainSeparator, , bytes32 contentsHash) = Permit2Utils.getPermit2Fixtures(permit, bob, address(setup.permit2));
        
            bytes32 msgHash = MessageHashUtils.toTypedDataHash(appDomainSeparator, contentsHash);
            sig = signerTestKey.sign(msgHash);
        }
        _testPermit2Transfer(setup.permit2, permit, sig, setup.spendAmount, setup.totalAmount, false, bytes32(0), "");
    }

    // Test that a permit2 witness signature can be used to transfer native ETH
    // using the ERC20-eth contract
    function test_permit2WitnessSignatureTransferNative() public {
        Permit2TestSetup memory setup = _setupPermit2Test();
        Permit2Utils.MockWitness memory witnessData = Permit2Utils.MockWitness(10000000, address(5), true);
        bytes32 witness = keccak256(abi.encode(witnessData));
        ISignatureTransfer.PermitTransferFrom memory permit = _createPermit(address(setup.erc20Eth), setup.spendAmount);
        
        bytes memory sig;
        {        
            (bytes32 appDomainSeparator, , bytes32 contentsHash) = Permit2Utils.getPermit2WitnessFixtures(permit, witness, bob, address(setup.permit2));
        
            bytes32 msgHash = MessageHashUtils.toTypedDataHash(appDomainSeparator, contentsHash);
            sig = signerTestKey.sign(msgHash);
        }
        _testPermit2Transfer(setup.permit2, permit, sig, setup.spendAmount, setup.totalAmount, true, witness, Permit2Utils.WITNESS_TYPE_STRING);
    }
}
