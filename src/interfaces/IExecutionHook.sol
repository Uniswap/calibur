// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IExecutionHook
/// @notice Hooks that are executed before and after a Call is executed
interface IExecutionHook {
    /// @dev Must revert if the entire call should revert.
    /// @param keyHash The key hash to check against
    /// @param to The address to call
    /// @param value value of the call
    /// @return Context to pass to afterExecute hook, if present. An empty bytes array MAY be returned.
    function beforeExecute(bytes32 keyHash, address to, uint256 value, bytes calldata data)
        external
        returns (bytes4, bytes memory);

    /// @dev Must revert if the entire call should revert.
    /// @param keyHash The key hash to check against
    /// @param success Whether the call succeeded
    /// @param output The output of the call
    /// @param beforeExecuteData The context returned by the beforeExecute hook.
    function afterExecute(bytes32 keyHash, bool success, bytes calldata output, bytes calldata beforeExecuteData)
        external
        returns (bytes4);
}
