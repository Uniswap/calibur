// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC1271} from "./interfaces/IERC1271.sol";

/// @title ERC-1271
/// @notice Abstract ERC1271 implementation which supports nested EIP-712 workflows as defined by ERC-7739
abstract contract ERC1271 is IERC1271 {
    /// @dev The magic value returned by `isValidSignature()` if the signature is valid.
    bytes4 internal constant _1271_MAGIC_VALUE = 0x1626ba7e;
    /// @dev The magic value returned by `isValidSignature()` if the signature is invalid.
    bytes4 internal constant _1271_INVALID_VALUE = 0xffffffff;

    /// @inheritdoc IERC1271
    function isValidSignature(bytes32 hash, bytes calldata signature) public view virtual returns (bytes4);
}
