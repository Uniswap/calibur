// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {UserOperationLib} from "account-abstraction/core/UserOperationLib.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

library UserOpBuilder {
    using UserOperationLib for PackedUserOperation;

    bytes32 constant DEFAULT_ACCOUNT_GAS_LIMITS = bytes32(uint256(1_000_000) << 128 | uint256(1_000_000));
    uint256 constant DEFAULT_PRE_VERIFICATION_GAS = 1_000_000;
    bytes32 constant DEFAULT_GAS_FEES = bytes32(uint256(100) << 128 | uint256(100));

    function initDefault() internal pure returns (PackedUserOperation memory) {
        return PackedUserOperation(
            address(0), 0, "", "", DEFAULT_ACCOUNT_GAS_LIMITS, DEFAULT_PRE_VERIFICATION_GAS, DEFAULT_GAS_FEES, "", ""
        );
    }

    /// @dev Override initcode hash set to default of 0
    function encode(PackedUserOperation calldata userOp) internal pure returns (bytes memory) {
        return userOp.encode(bytes32(0));
    }

    /// @dev Override initcode hash set to default of 0
    function hash(PackedUserOperation calldata userOp) internal pure returns (bytes32) {
        return userOp.hash(bytes32(0));
    }

    function withSender(PackedUserOperation memory userOp, address sender)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.sender = sender;
        return userOp;
    }

    function withNonce(PackedUserOperation memory userOp, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.nonce = nonce;
        return userOp;
    }

    function withCallData(PackedUserOperation memory userOp, bytes memory callData)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.callData = callData;
        return userOp;
    }

    function withAccountGasLimits(PackedUserOperation memory userOp, bytes32 accountGasLimits)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.accountGasLimits = accountGasLimits;
        return userOp;
    }

    function withPreVerificationGas(PackedUserOperation memory userOp, uint256 preVerificationGas)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.preVerificationGas = preVerificationGas;
        return userOp;
    }

    function withGasFees(PackedUserOperation memory userOp, bytes32 gasFees)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.gasFees = gasFees;
        return userOp;
    }

    function withPaymasterAndData(PackedUserOperation memory userOp, bytes memory paymasterAndData)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.paymasterAndData = paymasterAndData;
        return userOp;
    }

    function withSignature(PackedUserOperation memory userOp, bytes memory signature)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        userOp.signature = signature;
        return userOp;
    }
}
