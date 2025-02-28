// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IERC1271
interface IERC1271 {
    /// @notice Validates the `signature` against the given `hash`.
    /// @dev Hashes the given `hash` to be replay safe and validates the signature against it.
    ///
    /// @return result `0x1626ba7e` if validation succeeded, else `0xffffffff`.
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
}
