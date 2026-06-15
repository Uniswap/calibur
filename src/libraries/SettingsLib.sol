// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IHook} from "../interfaces/IHook.sol";

type Settings is uint256;

/// @title SettingsLib
/// @notice Key settings are packed into a uint256 where
/// - the least significant 20 bytes (0-19) specify an address to callout to for extra or overrideable validation.
/// - bytes 20-24 are used for the expiration timestamp.
/// - bit 200 specifies whether the key is an admin key.
/// - bits 201-255 are reserved for future use and must be unset.
///   bits 201-255 |  bit 200  | 5 bytes      | 20 bytes
///   RESERVED     |  isAdmin  | expiration   | hook
library SettingsLib {
    uint160 constant MASK_20_BYTES = uint160(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
    uint40 constant MASK_5_BYTES = uint40(0xFFFFFFFFFF);

    /// @notice Mask covering bits 201-255, which sit above the admin flag (bit 200) and are reserved for future use.
    ///         The admin flag is a single bit, so a settings word with these bits set is rejected on update.
    uint256 constant RESERVED_BITS = type(uint256).max << 201;

    Settings constant DEFAULT = Settings.wrap(0);
    // RootKey has the settings: (isAdmin = true, 0 expiration, no hook)
    Settings constant ROOT_KEY_SETTINGS = Settings.wrap(uint256(1) << 200);

    /// @notice Returns whether the key is an admin key
    function isAdmin(Settings settings) internal pure returns (bool _isAdmin) {
        assembly {
            _isAdmin := and(shr(200, settings), 1)
        }
    }

    /// @notice Returns the expiration timestamp in unix time
    function expiration(Settings settings) internal pure returns (uint40 _expiration) {
        uint40 mask = MASK_5_BYTES;
        assembly {
            _expiration := and(shr(160, settings), mask)
        }
    }

    /// @notice Returns the hook address of the key
    function hook(Settings settings) internal pure returns (IHook _hook) {
        uint256 mask = MASK_20_BYTES;
        assembly {
            _hook := and(settings, mask)
        }
    }

    /// @notice A key is expired if its expiration is less than the current block timestamp
    ///         Strictly less than is inline with how expiry is handled in the ERC-4337 EntryPoint contract
    /// @dev Keys with expiry of 0 never expire.
    function isExpired(Settings settings) internal view returns (bool _isExpired, uint40 _expiration) {
        uint40 _exp = expiration(settings);
        if (_exp == 0) return (false, 0);
        return (_exp < block.timestamp, _exp);
    }
}
