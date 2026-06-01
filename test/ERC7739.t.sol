// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {TokenHandler} from "./utils/TokenHandler.sol";
import {PermitSingle, PermitDetails, MockERC1271VerifyingContract} from "./utils/MockERC1271VerifyingContract.sol";
import {ERC1271Handler} from "./utils/ERC1271Handler.sol";
import {TestKeyManager, TestKey} from "./utils/TestKeyManager.sol";
import {KeyType, Key, KeyLib} from "../src/libraries/KeyLib.sol";
import {TypedDataSignBuilder} from "./utils/TypedDataSignBuilder.sol";
import {FFISignTypedData} from "./utils/FFISignTypedData.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Permit2Utils} from "./utils/Permit2Utils.sol";
import {IPermit2} from "../lib/permit2/src/interfaces/IPermit2.sol";
import {IAllowanceTransfer} from "../lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {PermitHash} from "../lib/permit2/src/libraries/PermitHash.sol";
import {ERC20ETH} from "../lib/erc20-eth/src/ERC20Eth.sol";

contract ERC7739Test is DelegationHandler, TokenHandler, ERC1271Handler, FFISignTypedData {
    using TestKeyManager for TestKey;
    using TypedDataSignBuilder for *;
    using KeyLib for Key;
    using Permit2Utils for *;
    using PermitHash for IAllowanceTransfer.PermitSingle;

    IAllowanceTransfer public permit2;
    bytes4 private constant _1271_MAGIC_VALUE = 0x1626ba7e;

    function setUp() public {
        setUpDelegation();
        setUpTokens();
        // Deploy permit2 for actual permit transfers
        permit2 = IAllowanceTransfer(Permit2Utils.deployPermit2());
    }

    function test_signPersonalSign_matches_signWrappedPersonalSign_ffi() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, signerPrivateKey);

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));
        bytes32 signerAccountDomainSeparator = signerAccount.domainSeparator();
        bytes32 wrappedPersonalSignDigest = messageHash.hashWrappedPersonalSign(signerAccountDomainSeparator);

        address verifyingContract = address(signerAccount);
        (,,,,, bytes32 salt,) = signerAccount.eip712Domain();

        (bytes memory signature) = ffi_signWrappedPersonalSign(signerPrivateKey, verifyingContract, salt, message);
        assertEq(signature, key.sign(wrappedPersonalSignDigest));
    }

    function test_signTypedSignData_matches_signWrappedTypedData_ffi() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, signerPrivateKey);

        PermitSingle memory permitSingle = PermitSingle({
            details: PermitDetails({token: address(0), amount: 0, expiration: 0, nonce: 0}),
            spender: address(0),
            sigDeadline: 0
        });
        // Locally generate the full TypedSignData hash
        bytes32 contentsHash = mockERC1271VerifyingContract.hash(permitSingle);
        bytes32 appSeparator = mockERC1271VerifyingContract.domainSeparator();
        string memory contentsDescrExplicit = mockERC1271VerifyingContract.contentsDescrExplicit();
        (string memory contentsName, string memory contentsType) =
            mockERC7739Utils.decodeContentsDescr(contentsDescrExplicit);

        bytes memory signerAccountDomainBytes = IERC5267(address(signerAccount)).toDomainBytes();
        bytes32 typedDataSignDigest =
            contentsHash.hashTypedDataSign(signerAccountDomainBytes, appSeparator, contentsName, contentsType);

        // Make it clear that the verifying contract is set properly.
        address verifyingContract = address(signerAccount);
        (,,,,, bytes32 salt,) = signerAccount.eip712Domain();

        (bytes memory signature) = ffi_signWrappedTypedData(
            signerPrivateKey,
            verifyingContract,
            salt,
            DOMAIN_NAME,
            DOMAIN_VERSION,
            address(mockERC1271VerifyingContract),
            permitSingle
        );
        // Assert that the signature is valid when compared against the ffi generated signature
        assertEq(signature, key.sign(typedDataSignDigest));
    }

    function test_signTypedSignData_usingImplicitType_wrongSignature_ffi() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, signerPrivateKey);

        PermitSingle memory permitSingle = PermitSingle({
            details: PermitDetails({token: address(0), amount: 0, expiration: 0, nonce: 0}),
            spender: address(0),
            sigDeadline: 0
        });
        // Locally generate the full TypedSignData hash
        bytes32 contentsHash = mockERC1271VerifyingContract.hash(permitSingle);
        bytes32 appSeparator = mockERC1271VerifyingContract.domainSeparator();

        // Incorrectly use the implicit type descriptor string, causing the top level type to be
        // TypeDataSign(...)PermitSingle(...)PermitDetails(...) which does not follow EIP-712 ordering
        string memory contentsDescrImplicit = mockERC1271VerifyingContract.contentsDescrImplicit();
        (string memory contentsName, string memory contentsType) =
            mockERC7739Utils.decodeContentsDescr(contentsDescrImplicit);

        bytes memory signerAccountDomainBytes = IERC5267(address(signerAccount)).toDomainBytes();
        bytes32 typedDataSignDigest =
            contentsHash.hashTypedDataSign(signerAccountDomainBytes, appSeparator, contentsName, contentsType);

        // Make it clear that the verifying contract is set properly.
        address verifyingContract = address(signerAccount);
        (,,,,, bytes32 salt,) = signerAccount.eip712Domain();

        (bytes memory signature) = ffi_signWrappedTypedData(
            signerPrivateKey,
            verifyingContract,
            salt,
            DOMAIN_NAME,
            DOMAIN_VERSION,
            address(mockERC1271VerifyingContract),
            permitSingle
        );
        // Assert that the ffi generated signature is NOT the same as the locally generated signature
        assertNotEq(signature, key.sign(typedDataSignDigest));
    }

    function test_signTypedSignData_permitSingleTransfer() public {
        // Register a test key with the signer account
        uint256 testPrivateKey = 0x123456;
        TestKey memory testKey = TestKeyManager.withSeed(KeyType.Secp256k1, testPrivateKey);
        vm.prank(address(signerAccount));
        signerAccount.register(testKey.toKey());

        // Give the signer account some tokens to permit
        uint256 initialBalance = 10000;
        deal(address(tokenA), address(signerAccount), initialBalance);

        // Approve permit2 to spend tokens on behalf of the signer account
        vm.prank(address(signerAccount));
        tokenA.approve(address(permit2), type(uint256).max);

        // Create a PermitSingle for permit2 (using permit2's actual domain)
        uint160 allowanceAmount = 1000;
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(tokenA), amount: allowanceAmount, expiration: uint48(block.timestamp + 1 hours), nonce: 0
            }),
            spender: address(this),
            sigDeadline: block.timestamp + 1 hours
        });

        // Generate the permit2 domain separator and hash
        bytes32 permit2DomainSeparator = permit2.DOMAIN_SEPARATOR();
        bytes32 permitHash = permitSingle.hash();

        // Build ERC-7739 TypedDataSign signature for permit2
        string memory contentsDescr =
            "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitSingle";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);

        bytes memory signerAccountDomainBytes = IERC5267(address(signerAccount)).toDomainBytes();
        bytes32 typedDataSignDigest =
            permitHash.hashTypedDataSign(signerAccountDomainBytes, permit2DomainSeparator, contentsName, contentsType);

        // Sign the digest with the test key
        bytes memory signature = testKey.sign(typedDataSignDigest);

        // Build the TypedDataSign signature for ERC-7739
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, permit2DomainSeparator, permitHash, contentsDescr
        );

        // Wrap the signature with keyHash and empty hook data
        bytes memory wrappedSignature = abi.encode(testKey.toKeyHash(), typedDataSignSignature, bytes(""));

        // Test by calling permit2.permit() which will internally call isValidSignature() on the signer account
        // This should succeed without reverting, proving the signature is valid
        permit2.permit(address(signerAccount), permitSingle, wrappedSignature);

        // Verify the allowance was actually set
        (uint160 allowance, uint48 expiration, uint48 nonce) =
            permit2.allowance(address(signerAccount), address(tokenA), address(this));
        assertEq(allowance, allowanceAmount);
        assertEq(expiration, uint48(block.timestamp + 1 hours));
        assertEq(nonce, 1); // nonce should be incremented after permit
    }

    function test_signTypedSignData_permitSingleTransfer_transferNative() public {
        // Register a test key with the signer account
        uint256 testPrivateKey = 0x123456;
        TestKey memory testKey = TestKeyManager.withSeed(KeyType.Secp256k1, testPrivateKey);
        vm.prank(address(signerAccount));
        signerAccount.register(testKey.toKey());

        // Deploy ERC20ETH contract for native ETH transfers
        ERC20ETH erc20Eth = new ERC20ETH();

        // Give the signer account some ETH
        uint256 initialEthBalance = 10 ether;
        vm.deal(address(signerAccount), initialEthBalance);

        // Approve ERC20ETH to spend native ETH on behalf of the signer account
        vm.prank(address(signerAccount));
        signerAccount.approveNative(address(erc20Eth), type(uint256).max);

        // Create a PermitSingle for permit2 using ERC20ETH
        uint160 allowanceAmount = 1 ether;
        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(erc20Eth),
                amount: allowanceAmount,
                expiration: uint48(block.timestamp + 1 hours),
                nonce: 0
            }),
            spender: address(this),
            sigDeadline: block.timestamp + 1 hours
        });

        // Generate the permit2 domain separator and hash
        bytes32 permit2DomainSeparator = permit2.DOMAIN_SEPARATOR();
        bytes32 permitHash = permitSingle.hash();

        // Build ERC-7739 TypedDataSign signature for permit2
        string memory contentsDescr =
            "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitSingle";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);

        bytes memory signerAccountDomainBytes = IERC5267(address(signerAccount)).toDomainBytes();
        bytes32 typedDataSignDigest =
            permitHash.hashTypedDataSign(signerAccountDomainBytes, permit2DomainSeparator, contentsName, contentsType);

        // Sign the digest with the test key
        bytes memory signature = testKey.sign(typedDataSignDigest);

        // Build the TypedDataSign signature for ERC-7739
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, permit2DomainSeparator, permitHash, contentsDescr
        );

        // Wrap the signature with keyHash and empty hook data
        bytes memory wrappedSignature = abi.encode(testKey.toKeyHash(), typedDataSignSignature, bytes(""));

        // Test by calling permit2.permit() which will internally call isValidSignature() on the signer account
        // This should succeed without reverting, proving the signature is valid
        permit2.permit(address(signerAccount), permitSingle, wrappedSignature);

        // Verify the allowance was actually set
        (uint160 allowance, uint48 expiration, uint48 nonce) =
            permit2.allowance(address(signerAccount), address(erc20Eth), address(this));
        assertEq(allowance, allowanceAmount);
        assertEq(expiration, uint48(block.timestamp + 1 hours));
        assertEq(nonce, 1); // nonce should be incremented after permit

        // Now verify the spender can actually pull the ETH
        address recipient = address(0xBEEF);
        uint160 transferAmount = 0.5 ether;

        // Check initial ETH balances
        uint256 signerEthBalanceBefore = address(signerAccount).balance;
        uint256 recipientEthBalanceBefore = recipient.balance;

        // Verify wrong spender cannot transfer ETH
        address wrongSpender = address(0xBAD);
        vm.expectRevert(); // Should revert with insufficient allowance
        vm.prank(wrongSpender);
        permit2.transferFrom(address(signerAccount), wrongSpender, 1, address(erc20Eth));

        // Verify correct spender cannot exceed allowance limit
        vm.expectRevert(); // Should revert with insufficient allowance
        permit2.transferFrom(address(signerAccount), recipient, allowanceAmount + 1, address(erc20Eth));

        // Transfer ETH using the permit
        permit2.transferFrom(address(signerAccount), recipient, transferAmount, address(erc20Eth));

        // Verify ETH balances changed correctly
        assertEq(address(signerAccount).balance, signerEthBalanceBefore - transferAmount);
        assertEq(recipient.balance, recipientEthBalanceBefore + transferAmount);

        // Verify allowance was decremented
        (uint160 allowanceAfter,,) = permit2.allowance(address(signerAccount), address(erc20Eth), address(this));
        assertEq(allowanceAfter, allowanceAmount - transferAmount);

        // Transfer remaining allowed ETH
        permit2.transferFrom(address(signerAccount), recipient, allowanceAmount - transferAmount, address(erc20Eth));

        // Verify final ETH balances
        assertEq(address(signerAccount).balance, initialEthBalance - allowanceAmount);
        assertEq(recipient.balance, allowanceAmount);

        // Verify allowance is now zero
        (uint160 finalAllowance,,) = permit2.allowance(address(signerAccount), address(erc20Eth), address(this));
        assertEq(finalAllowance, 0);
    }
}
