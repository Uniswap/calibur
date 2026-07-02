// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEIP712} from "./interfaces/IEIP712.sol";
import {BaseAuthorization} from "./BaseAuthorization.sol";
import {PrefixedSaltLib} from "./libraries/PrefixedSaltLib.sol";

/// @title EIP712
/// @dev This contract does not cache the domain separator and instead calculates it on the fly
///      since it will change when delegated to or when the salt is updated.
/// @notice It is not compatible with use by proxy contracts since the domain name and version are cached on deployment.
contract EIP712 is IEIP712, IERC5267, BaseAuthorization {
    using PrefixedSaltLib for uint96;
    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)")`.

    bytes32 internal constant _DOMAIN_TYPEHASH = 0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472;

    /// @dev Cached name and version hashes for cheaper runtime gas costs.
    bytes32 private immutable _cachedNameHash;
    bytes32 private immutable _cachedVersionHash;
    address private immutable _cachedImplementation;

    /// @dev Any prefix to be added to the salt. This can be updated by the owner or an admin but it defaults to 0.
    uint96 private _saltPrefix;

    constructor() {
        string memory name;
        string memory version;
        (name, version) = _domainNameAndVersion();
        _cachedNameHash = keccak256(bytes(name));
        _cachedVersionHash = keccak256(bytes(version));
        _cachedImplementation = address(this);
    }

    /// @notice Returns information about the `EIP712Domain` used to create EIP-712 compliant hashes.
    ///
    /// @dev Follows ERC-5267 (see https://eips.ethereum.org/EIPS/eip-5267).
    ///
    /// @return fields The bitmap of used fields.
    /// @return name The value of the `EIP712Domain.name` field.
    /// @return version The value of the `EIP712Domain.version` field.
    /// @return chainId The value of the `EIP712Domain.chainId` field.
    /// @return verifyingContract The value of the `EIP712Domain.verifyingContract` field.
    /// @return salt The value of the `EIP712Domain.salt` field.
    /// @return extensions The list of EIP numbers, that extends EIP-712 with new domain fields.
    function eip712Domain()
        public
        view
        virtual
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        fields = hex"1f"; // `0b11111`.
        (name, version) = _domainNameAndVersion();
        chainId = block.chainid;
        verifyingContract = address(this);
        salt = _saltPrefix.pack(_cachedImplementation);
        extensions = new uint256[](0);
    }

    /// @inheritdoc IEIP712
    function domainBytes() public view returns (bytes memory) {
        // _eip712Domain().fields and _eip712Domain().extensions are not used
        (,,, uint256 chainId, address verifyingContract, bytes32 salt,) = eip712Domain();
        return abi.encode(_cachedNameHash, _cachedVersionHash, chainId, verifyingContract, salt);
    }

    /// @inheritdoc IEIP712
    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                _DOMAIN_TYPEHASH,
                _cachedNameHash,
                _cachedVersionHash,
                block.chainid,
                address(this),
                _saltPrefix.pack(_cachedImplementation)
            )
        );
    }

    /// @inheritdoc IEIP712
    function hashTypedData(bytes32 hash) public view virtual returns (bytes32) {
        return MessageHashUtils.toTypedDataHash(domainSeparator(), hash);
    }

    /// @inheritdoc IEIP712
    function updateSalt() external onlyThis {
        _saltPrefix++;
        // per EIP-5267, emit an event to notify that the domain separator has changed
        emit EIP712DomainChanged();
    }

    /// @notice Returns the domain name and version to use when creating EIP-712 signatures.
    /// @return name    The user readable name of signing domain.
    /// @return version The current major version of the signing domain.
    function _domainNameAndVersion() internal pure returns (string memory name, string memory version) {
        return ("Calibur", "1.0.0");
    }
}
