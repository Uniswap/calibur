// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC7739Utils} from "@openzeppelin/contracts/utils/cryptography/draft-ERC7739Utils.sol";

/// @title TypedDataSignBuilder
/// @notice A library to help build ERC-7739 nested typed data signatures
/// @dev Typed data digests are built via `MockERC7739Utils.hashTypedDataSign` because OpenZeppelin's
///      `typedDataSignStructHash` takes `string calldata` arguments which cannot be supplied from this
///      `pure` library when callers hold `memory` strings.
library TypedDataSignBuilder {
    /// @notice Helper function to extract the domain bytes from a contract which implements EIP-5267
    function toDomainBytes(IERC5267 account) internal view returns (bytes memory) {
        (, string memory name, string memory version, uint256 chainId, address verifyingContract, bytes32 salt,) =
            account.eip712Domain();
        return abi.encode(keccak256(bytes(name)), keccak256(bytes(version)), chainId, verifyingContract, salt);
    }

    /// @notice Produces an EIP-712 compatible digest by hashing an ERC-191 signed personal message against the provided domain separator
    function hashWrappedPersonalSign(bytes32 messageHash, bytes32 domainSeparator) internal pure returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(domainSeparator, ERC7739Utils.personalSignStructHash(messageHash));
    }

    /// @notice Builds a nested typed data sign signature
    function buildTypedDataSignSignature(
        bytes memory signature,
        bytes32 appSeparator,
        bytes32 contentsHash,
        string memory contentsDescr
    ) internal pure returns (bytes memory) {
        return ERC7739Utils.encodeTypedDataSig(signature, appSeparator, contentsHash, contentsDescr);
    }
}
