// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {IKeyManagement} from "./interfaces/IKeyManagement.sol";
import {BaseAuthorization} from "./BaseAuthorization.sol";
import {Key, KeyLib} from "./libraries/KeyLib.sol";
import {Settings, SettingsLib} from "./libraries/SettingsLib.sol";
import {HooksLib} from "./libraries/HooksLib.sol";
import {IHook} from "./interfaces/IHook.sol";

/// @dev A base contract for managing keys
abstract contract KeyManagement is IKeyManagement, BaseAuthorization {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using KeyLib for *;
    using SettingsLib for Settings;

    EnumerableSetLib.Bytes32Set public keyHashes;
    mapping(bytes32 keyHash => bytes encodedKey) private keyStorage;
    mapping(bytes32 keyHash => Settings settings) private keySettings;

    /// @inheritdoc IKeyManagement
    function register(Key memory key) external onlyThis {
        if (key.isRootKey()) revert CannotRegisterRootKey();
        if (!key.isValidPublicKey()) revert InvalidKey();

        _checkCanRegister(key);

        bytes32 keyHash = key.hash();
        keyStorage[keyHash] = abi.encode(key);
        keyHashes.add(keyHash);

        emit Registered(keyHash, key);
    }

    /// @inheritdoc IKeyManagement
    function update(bytes32 keyHash, Settings settings) external onlyThis {
        if (keyHash.isRootKey()) revert CannotUpdateRootKey();
        if (!isRegistered(keyHash)) revert KeyDoesNotExist();
        // The upper bits are reserved for future use and definition, so they must be unset
        if (Settings.unwrap(settings) & SettingsLib.RESERVED_BITS != 0) revert InvalidSettings();

        // Reject a hook with no enabled callbacks or no deployed code
        address hook = address(settings.hook());
        if (hook != address(0) && (uint160(hook) & HooksLib.ALL_FLAGS == 0 || hook.code.length == 0)) {
            revert InvalidHook();
        }

        keySettings[keyHash] = settings;
        emit KeySettingsUpdated(keyHash, settings);
    }

    /// @inheritdoc IKeyManagement
    function revoke(bytes32 keyHash) external onlyThis {
        if (!keyHashes.remove(keyHash)) revert KeyDoesNotExist();
        delete keyStorage[keyHash];
        keySettings[keyHash] = SettingsLib.DEFAULT;

        emit Revoked(keyHash);
    }

    /// @inheritdoc IKeyManagement
    function keyCount() external view returns (uint256) {
        return keyHashes.length();
    }

    /// @inheritdoc IKeyManagement
    function keyAt(uint256 i) external view returns (Key memory) {
        return getKey(keyHashes.at(i));
    }

    /// @inheritdoc IKeyManagement
    function getKey(bytes32 keyHash) public view returns (Key memory) {
        if (keyHash.isRootKey()) return KeyLib.toRootKey();
        if (isRegistered(keyHash)) return abi.decode(keyStorage[keyHash], (Key));
        revert KeyDoesNotExist();
    }

    /// @inheritdoc IKeyManagement
    function getKeySettings(bytes32 keyHash) public view returns (Settings) {
        if (keyHash.isRootKey()) return SettingsLib.ROOT_KEY_SETTINGS;
        if (isRegistered(keyHash)) return keySettings[keyHash];
        revert KeyDoesNotExist();
    }

    /// @inheritdoc IKeyManagement
    function isRegistered(bytes32 keyHash) public view returns (bool) {
        return keyHashes.contains(keyHash);
    }

    /// @notice Hook for additional validation before a key is registered
    /// @dev Defaults to a no-op; overridden by implementations that reserve certain keys
    function _checkCanRegister(Key memory key) internal view virtual {}

    /// @notice Reverts if the key settings are expired
    function _checkExpiry(Settings settings) internal view {
        (bool isExpired, uint40 expiry) = settings.isExpired();
        if (isExpired) revert IKeyManagement.KeyExpired(expiry);
    }

    /// @notice Check if the keyHash is the root key or a registered, unexpired key
    function _isOwnerOrValidKey(bytes32 keyHash) internal view returns (bool) {
        if (keyHash.isRootKey()) return true;
        if (!isRegistered(keyHash)) return false;
        (bool isExpired,) = keySettings[keyHash].isExpired();
        return !isExpired;
    }
}
