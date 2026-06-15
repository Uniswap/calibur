// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC7739Utils} from "@openzeppelin/contracts/utils/cryptography/draft-ERC7739Utils.sol";
import {Key, KeyLib} from "./libraries/KeyLib.sol";
import {WrappedSignatureLib} from "./libraries/WrappedSignatureLib.sol";

/// @title ERC7739
/// @notice An abstract contract that implements the ERC-7739 standard
/// @notice This contract assumes that all data verified through ERC-1271 `isValidSignature` implements the defensive nested hashing scheme defined in EIP-7739
/// @dev See https://eips.ethereum.org/EIPS/eip-7739
abstract contract ERC7739 {
    using WrappedSignatureLib for bytes;
    using ERC7739Utils for *;
    using KeyLib for Key;

    /// @notice Verifies that the claimed contentsHash hashed with the app's separator matches the isValidSignature provided data
    /// @dev This is a necessary check to ensure that the contentsHash and appSeparator provided in the signature are correct
    /// @param appSeparator The app's domain separator
    /// @param hash The data provided in `isValidSignature`
    /// @param contentsHash The hash of the contents, i.e. hashStruct(contents)
    function _callerHashMatchesReconstructedHash(bytes32 appSeparator, bytes32 hash, bytes32 contentsHash)
        private
        pure
        returns (bool)
    {
        return hash == MessageHashUtils.toTypedDataHash(appSeparator, contentsHash);
    }

    /// @notice Decodes the data for TypedDataSign and verifies the signature against the key over the hash
    /// @dev Performs the required checks per the ERC-7739 spec:
    /// - contentsName and contentsType are not empty
    /// - The reconstructed hash matches the hash passed in via isValidSignature
    function _isValidTypedDataSig(
        Key memory key,
        bytes32 digest,
        bytes memory domainBytes,
        bytes calldata wrappedSignature
    ) internal view returns (bool) {
        (bytes calldata signature, bytes32 appSeparator, bytes32 contentsHash, string calldata contentsDescr) =
            wrappedSignature.decodeTypedDataSig();

        if (!_callerHashMatchesReconstructedHash(appSeparator, digest, contentsHash)) return false;

        (string calldata contentsName, string calldata contentsType) = contentsDescr.decodeContentsDescr();
        // For safety, ERC-7739 recommends to treat the signature as invalid if either the contentsName or contentsType are empty
        if (bytes(contentsName).length == 0 || bytes(contentsType).length == 0) return false;

        bytes32 nestedDigest = MessageHashUtils.toTypedDataHash(
            appSeparator, ERC7739Utils.typedDataSignStructHash(contentsName, contentsType, contentsHash, domainBytes)
        );

        return key.verify(nestedDigest, signature);
    }

    /// @notice Verifies a personal sign signature against the key over the hash
    function _isValidNestedPersonalSig(
        Key memory key,
        bytes32 digest,
        bytes32 domainSeparator,
        bytes calldata signature
    ) internal view returns (bool) {
        return key.verify(
            MessageHashUtils.toTypedDataHash(domainSeparator, ERC7739Utils.personalSignStructHash(digest)), signature
        );
    }
}
