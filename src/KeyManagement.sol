// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {Key, KeyLib, KeyType} from "./libraries/KeyLib.sol";
import {MinimalDelegationStorage, MinimalDelegationStorageLib} from "./libraries/MinimalDelegationStorage.sol";
import {IKeyManagement} from "./interfaces/IKeyManagement.sol";
import {IHook} from "./interfaces/IHook.sol";
import {Settings, SettingsLib} from "./libraries/SettingsLib.sol";

/// @dev A base contract for managing keys.
abstract contract KeyManagement is IKeyManagement {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using KeyLib for Key;

    /// @dev Must be overridden by the implementation
    function _onlyThis() internal view virtual {}

    /// @inheritdoc IKeyManagement
    function register(Key memory key) external {
        _onlyThis();

        bytes32 keyHash = key.hash();
        // If the keyHash already exists, it does not revert and updates the key instead.
        MinimalDelegationStorage storage minimalDelegationStorage = MinimalDelegationStorageLib.get();
        minimalDelegationStorage.keyStorage[keyHash] = abi.encode(key);
        minimalDelegationStorage.keyHashes.add(keyHash);

        emit Registered(keyHash, key);
    }

    function update(bytes32 keyHash, Settings settings) external {
        _onlyThis();
        MinimalDelegationStorage storage minimalDelegationStorage = MinimalDelegationStorageLib.get();
        if (!minimalDelegationStorage.keyHashes.contains(keyHash)) revert KeyDoesNotExist();

        minimalDelegationStorage.keySettings[keyHash] = settings;
    }

    /// @inheritdoc IKeyManagement
    function revoke(bytes32 keyHash) external {
        _onlyThis();
        _revoke(keyHash);
        emit Revoked(keyHash);
    }

    /// @inheritdoc IKeyManagement
    function keyCount() external view returns (uint256) {
        return MinimalDelegationStorageLib.get().keyHashes.length();
    }

    /// @inheritdoc IKeyManagement
    function keyAt(uint256 i) external view returns (Key memory) {
        return _getKey(MinimalDelegationStorageLib.get().keyHashes.at(i));
    }

    /// @inheritdoc IKeyManagement
    function getKey(bytes32 keyHash) external view returns (Key memory) {
        return _getKey(keyHash);
    }

    /// @inheritdoc IKeyManagement
    function getKeySettings(bytes32 keyHash) external view returns (Settings) {
        return MinimalDelegationStorageLib.get().keySettings[keyHash];
    }

    function _revoke(bytes32 keyHash) internal {
        MinimalDelegationStorage storage minimalDelegationStorage = MinimalDelegationStorageLib.get();
        delete minimalDelegationStorage.keyStorage[keyHash];
        minimalDelegationStorage.keySettings[keyHash] = SettingsLib.DEFAULT;

        if (!minimalDelegationStorage.keyHashes.remove(keyHash)) {
            revert KeyDoesNotExist();
        }
    }

    function _getKey(bytes32 keyHash) internal view returns (Key memory) {
        if (keyHash == bytes32(0)) return KeyLib.toRootKey();
        bytes memory data = MinimalDelegationStorageLib.get().keyStorage[keyHash];
        if (data.length == 0) revert KeyDoesNotExist();
        return abi.decode(data, (Key));
    }
}
