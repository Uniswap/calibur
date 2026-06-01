// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// Structs mirroring Permit2's PermitSingle and PermitDetails
/// These were chosen because when nested, per EIP-712, PermitSingle should be alphabetically ordered after PermitDetails
struct PermitSingle {
    PermitDetails details;
    address spender;
    uint256 sigDeadline;
}

struct PermitDetails {
    address token;
    uint160 amount;
    uint48 expiration;
    uint48 nonce;
}

/// @title MockERC1271VerifyingContract
/// @notice A mock contract mirroring Permit2 which implements nested EIP-712 data structures
/// @dev This contract is used to generate signatures for testing against our ERC-7739 implementation
contract MockERC1271VerifyingContract is EIP712 {
    bytes32 public constant _PERMIT_SINGLE_TYPEHASH = keccak256(
        "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)"
    );

    bytes32 public constant _PERMIT_DETAILS_TYPEHASH =
        keccak256("PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)");

    constructor(string memory name, string memory version) EIP712(name, version) {}

    /// @notice Public getter for the EIP-712 name
    function EIP712Name() external view returns (string memory) {
        return _EIP712Name();
    }

    /// @notice Public getter for the EIP-712 version
    function EIP712Version() external view returns (string memory) {
        return _EIP712Version();
    }

    /// @notice Public getter for the domain separator
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @notice The EIP-712 typestring with PermitSingle as the top level type
    /// @dev This should NOT be used for correct ERC-7739 nested TypedDataSign signatures
    function contentsDescrImplicit() external pure returns (string memory) {
        return "PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)";
    }

    /// @notice Per ERC-7739, use the explicit mode for content descriptor strings since the top level type
    ///         PermitSingle is alphabetically ordered after PermitDetails
    /// @dev return the full contents descriptor string in explicit mode
    function contentsDescrExplicit() external pure returns (string memory) {
        return "PermitDetails(address token,uint160 amount,uint48 expiration,uint48 nonce)PermitSingle(PermitDetails details,address spender,uint256 sigDeadline)PermitSingle";
    }

    /// @notice Apply EIP-7127 hashStruct to the PermitSingle struct
    function hash(PermitSingle memory permitSingle) public pure returns (bytes32) {
        bytes32 permitHash = _hashPermitDetails(permitSingle.details);
        return
            keccak256(abi.encode(_PERMIT_SINGLE_TYPEHASH, permitHash, permitSingle.spender, permitSingle.sigDeadline));
    }

    function _hashPermitDetails(PermitDetails memory details) private pure returns (bytes32) {
        return keccak256(abi.encode(_PERMIT_DETAILS_TYPEHASH, details));
    }

    /// @notice Return EIP-712 typed data using this contract's domain separator and the given data hash
    /// @dev assumes dataHash is the output of hashStruct
    function hashTypedDataV4(bytes32 dataHash) public view returns (bytes32) {
        return _hashTypedDataV4(dataHash);
    }

    /// Testing functions to return default values

    function defaultContents() public pure returns (PermitSingle memory) {
        return PermitSingle({
            details: PermitDetails({token: address(0), amount: 0, expiration: 0, nonce: 0}),
            spender: address(0),
            sigDeadline: 0
        });
    }

    function defaultContentsHash() public pure returns (bytes32) {
        return hash(defaultContents());
    }
}
