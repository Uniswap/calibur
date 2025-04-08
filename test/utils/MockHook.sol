// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {IHook} from "src/interfaces/IHook.sol";
import {IValidationHook} from "src/interfaces/IValidationHook.sol";
import {IExecutionHook} from "src/interfaces/IExecutionHook.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

contract MockHook is IHook {
    bool internal _verifySignatureReturnValue;
    bytes4 internal _isValidSignatureReturnValue;
    uint256 internal _validateUserOpReturnValue;
    bytes internal _beforeExecuteReturnValue;
    bytes internal _beforeExecuteRevertData;

    function setVerifySignatureReturnValue(bool returnValue) external {
        _verifySignatureReturnValue = returnValue;
    }

    function setIsValidSignatureReturnValue(bytes4 returnValue) external {
        _isValidSignatureReturnValue = returnValue;
    }

    function setValidateUserOpReturnValue(uint256 returnValue) external {
        _validateUserOpReturnValue = returnValue;
    }

    function setBeforeExecuteReturnValue(bytes memory returnValue) external {
        _beforeExecuteReturnValue = returnValue;
    }

    function setBeforeExecuteRevertData(bytes memory revertData) external {
        _beforeExecuteRevertData = revertData;
    }

    function overrideValidateUserOp(bytes32, PackedUserOperation calldata, bytes32)
        external
        view
        returns (bytes4, uint256)
    {
        return (IValidationHook.overrideValidateUserOp.selector, _validateUserOpReturnValue);
    }

    function overrideIsValidSignature(bytes32, bytes32, bytes calldata) external view returns (bytes4, bytes4) {
        return (IValidationHook.overrideIsValidSignature.selector, _isValidSignatureReturnValue);
    }

    function overrideVerifySignature(bytes32, bytes32, bytes calldata) external view returns (bytes4, bool) {
        return (IValidationHook.overrideVerifySignature.selector, _verifySignatureReturnValue);
    }

    function beforeExecute(bytes32, address, uint256, bytes calldata) external view returns (bytes4, bytes memory) {
        if (_beforeExecuteRevertData.length > 0) {
            bytes memory revertData = abi.encode(_beforeExecuteRevertData);
            assembly {
                revert(add(revertData, 32), mload(revertData))
            }
        }
        return (IExecutionHook.beforeExecute.selector, _beforeExecuteReturnValue);
    }

    function afterExecute(bytes32, bytes calldata) external pure returns (bytes4) {
        return (IExecutionHook.afterExecute.selector);
    }
}
