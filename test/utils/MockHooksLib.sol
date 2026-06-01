// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {HooksLib} from "src/libraries/HooksLib.sol";
import {IHook} from "src/interfaces/IHook.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

/// @title MockHooksLib
/// @notice A mock implementation of the HooksLib contract for testing purposes
contract MockHooksLib {
    using HooksLib for IHook;

    function handleAfterValidateUserOp(
        IHook self,
        bytes32 keyHash,
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 validationData,
        bytes calldata hookData
    ) external view {
        self.handleAfterValidateUserOp(keyHash, userOp, userOpHash, validationData, hookData);
    }

    function handleAfterIsValidSignature(IHook self, bytes32 keyHash, bytes32 digest, bytes calldata signature)
        external
        view
    {
        self.handleAfterIsValidSignature(keyHash, digest, signature);
    }

    function handleAfterVerifySignature(IHook self, bytes32 keyHash, bytes32 digest, bytes calldata signature)
        external
        view
    {
        self.handleAfterVerifySignature(keyHash, digest, signature);
    }

    function handleBeforeExecute(IHook self, bytes32 keyHash, address to, uint256 value, bytes calldata data) external {
        self.handleBeforeExecute(keyHash, to, value, data);
    }

    function handleAfterExecute(
        IHook self,
        bytes32 keyHash,
        bool success,
        bytes calldata output,
        bytes calldata returnData
    ) external {
        self.handleAfterExecute(keyHash, success, output, returnData);
    }
}
