// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {KeyType, Key, KeyLib} from "../../src/libraries/KeyLib.sol";

/// @title MockKeyLib
/// @notice A mock implementation of the KeyLib for testing purposes since the library uses address(this)
/// @dev Does not implement verify since it is tested in other tests
contract MockKeyLib {
    using KeyLib for Key;

    function hash(Key memory key) public pure returns (bytes32) {
        return key.hash();
    }

    function isRootKey(bytes32 keyHash) public pure returns (bool) {
        return keyHash == KeyLib.ROOT_KEY_HASH;
    }

    function isRootKey(Key memory key) public view returns (bool) {
        return key.keyType == KeyType.Secp256k1 && abi.decode(key.publicKey, (address)) == address(this);
    }

    function toRootKey() public view returns (Key memory) {
        return KeyLib.toRootKey();
    }

    function toKeyHash(address caller) public view returns (bytes32) {
        return KeyLib.toKeyHash(caller);
    }

    function verify(Key calldata key, bytes32 digest, bytes calldata signature) public view returns (bool) {
        return KeyLib.verify(key, digest, signature);
    }

    function isValidPublicKey(Key memory key) public pure returns (bool) {
        return key.isValidPublicKey();
    }
}
