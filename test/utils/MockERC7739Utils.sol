// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC7739Utils} from "@openzeppelin/contracts/utils/cryptography/draft-ERC7739Utils.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title MockERC7739Utils
/// @notice Mock contract to test OpenZeppelin's ERC7739Utils library functions and to provide a
///         calldata boundary so tests holding `memory` strings can reach the calldata-based helpers.
contract MockERC7739Utils {
    function decodeContentsDescr(string calldata contentsDescr)
        public
        pure
        returns (string memory contentsName, string memory contentsType)
    {
        return ERC7739Utils.decodeContentsDescr(contentsDescr);
    }

    function decodeTypedDataSig(bytes calldata encodedSignature)
        public
        pure
        returns (bytes memory signature, bytes32 appSeparator, bytes32 contentsHash, string memory contentsDescr)
    {
        return ERC7739Utils.decodeTypedDataSig(encodedSignature);
    }

    /// @notice Produces an EIP-712 compatible digest by hashing a TypedDataSign struct against the app's domain separator
    function hashTypedDataSign(
        bytes32 contentsHash,
        bytes memory domainBytes,
        bytes32 appSeparator,
        string calldata contentsName,
        string calldata contentsType
    ) public pure returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(
            appSeparator, ERC7739Utils.typedDataSignStructHash(contentsName, contentsType, contentsHash, domainBytes)
        );
    }
}
