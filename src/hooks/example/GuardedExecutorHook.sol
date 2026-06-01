// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {IExecutionHook} from "../../interfaces/IExecutionHook.sol";
import {AccountKeyHash, AccountKeyHashLib} from "../shared/AccountKeyHashLib.sol";

interface IGuardedExecutorHook is IExecutionHook {
    /// @notice Thrown when a key is not authorized to execute a call.
    error Unauthorized();
    /// @notice Thrown when a self call is not allowed.
    error SelfCallNotAllowed();
    // For testing convenience

    /// @notice Sentinel value which represents any key hash.
    function ANY_KEYHASH() external view returns (bytes32);
    /// @notice Sentinel value which represents any target address.
    function ANY_TARGET() external view returns (address);
    /// @notice Sentinel value which represents any function selector.
    function ANY_FN_SEL() external view returns (bytes4);

    /// @notice Set the canExecute flag for a keyHash, to, and selector.
    /// @dev Note that this hook does not support restricting any `value` sent along with the call
    /// @param keyHash the bytes32 keyHash
    /// @param to the target address
    /// @param selector the function selector
    /// @param can flag to set
    function setCanExecute(bytes32 keyHash, address to, bytes4 selector, bool can) external;
}

/// @title GuardedExecutorHook
/// @notice This is an example implementation of a hook which restricts keys from executing calls
///         based on the target address and function selector.
/// @notice For educational purposes only. This is unaudited code. Do not use this hook in production.
/// @author modified from https://github.com/ithacaxyz/account/blob/main/src/GuardedExecutor.sol
contract GuardedExecutorHook is IGuardedExecutorHook {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using AccountKeyHashLib for bytes32;

    mapping(AccountKeyHash => EnumerableSetLib.Bytes32Set) private canExecute;

    ////////////////////////////////////////////////////////////////////////
    // Constants
    ////////////////////////////////////////////////////////////////////////

    /// @dev Represents any key hash.
    bytes32 public constant ANY_KEYHASH = 0x3232323232323232323232323232323232323232323232323232323232323232;

    /// @dev Represents any target address.
    address public constant ANY_TARGET = 0x3232323232323232323232323232323232323232;

    /// @dev Represents any function selector.
    bytes4 public constant ANY_FN_SEL = 0x32323232;

    /// @dev Represents empty calldata.
    /// An empty calldata does not have 4 bytes for a function selector,
    /// and we will use this special value to denote empty calldata.
    bytes4 public constant EMPTY_CALLDATA_FN_SEL = 0xe0e0e0e0;

    /// @notice Set the canExecute flag for a keyHash, to, and selector
    function setCanExecute(bytes32 keyHash, address to, bytes4 selector, bool can) external {
        _setCanExecute(keyHash, to, selector, can);
    }

    /// @dev This will hash the keyHash with the sender's account address
    function _setCanExecute(bytes32 keyHash, address to, bytes4 selector, bool can) internal {
        canExecute[keyHash.wrap(msg.sender)].update(_packCanExecute(to, selector), can, 2048);
    }

    /// @dev Returns true if the key has the required permissions to execute the call.
    function _canExecute(bytes32 keyHash, address to, bytes calldata data) public view returns (bool) {
        // EOA keyhash can execute any call.
        if (keyHash == bytes32(0)) return true;

        bytes4 fnSel = ANY_FN_SEL;

        // If the calldata has 4 or more bytes, we can assume that the leading 4 bytes
        // denotes the function selector.
        if (data.length >= 4) fnSel = bytes4(LibBytes.loadCalldata(data, 0x00));

        // If the calldata is empty, make sure that the empty calldata has been authorized.
        if (data.length == uint256(0)) fnSel = EMPTY_CALLDATA_FN_SEL;

        // This check is required to ensure that authorizing any function selector
        // or any target will still NOT allow for self execution.
        if (_isSelfCall(to, fnSel)) return false;

        EnumerableSetLib.Bytes32Set storage c = canExecute[keyHash.wrap(msg.sender)];
        if (c.length() != 0) {
            if (c.contains(_packCanExecute(to, fnSel))) return true;
            if (c.contains(_packCanExecute(to, ANY_FN_SEL))) return true;
            if (c.contains(_packCanExecute(ANY_TARGET, fnSel))) return true;
            if (c.contains(_packCanExecute(ANY_TARGET, ANY_FN_SEL))) return true;
        }

        return false;
    }

    function beforeExecute(bytes32 keyHash, address to, uint256, bytes calldata data)
        external
        view
        override
        returns (bytes4, bytes memory)
    {
        // TODO: check value
        if (!_canExecute(keyHash, to, data)) revert Unauthorized();
        return (IExecutionHook.beforeExecute.selector, bytes(""));
    }

    /// @dev This hook is a no-op.
    function afterExecute(bytes32, bool, bytes calldata, bytes calldata) external pure override returns (bytes4) {
        return IExecutionHook.afterExecute.selector;
    }

    /// @dev Returns true if the call is to the same contract.
    function _isSelfCall(address to, bytes4) internal view returns (bool) {
        return to == msg.sender;
    }

    /// @dev Returns a bytes32 value that contains `to` and `selector`.
    function _packCanExecute(address to, bytes4 selector) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            result := or(shl(96, to), shr(224, selector))
        }
    }
}
