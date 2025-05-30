// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Settings, SettingsLib} from "../../src/libraries/SettingsLib.sol";
import {SettingsBuilder} from "../utils/SettingsBuilder.sol";
import {IHook} from "../../src/interfaces/IHook.sol";

contract SettingsLibTest is Test {
    using SettingsBuilder for Settings;
    using SettingsLib for Settings;

    function test_settings_default_values() public pure {
        Settings settings = SettingsBuilder.init(); // (Settings.wrap(0))
        assertEq(settings.expiration(), 0);
        assertEq(settings.isAdmin(), false);
        assertEq(address(settings.hook()), address(0));
    }

    function test_expiration_fuzz(uint40 expiration) public pure {
        Settings settings = SettingsBuilder.init().fromExpiration(expiration);
        assertEq(settings.expiration(), expiration);
    }

    function test_isAdmin() public pure {
        bool isAdmin = true;
        Settings settings = SettingsBuilder.init().fromIsAdmin(isAdmin);
        assertEq(settings.isAdmin(), isAdmin);
    }

    function test_isAdmin_fuzz(uint256 _settings) public pure {
        uint8 isAdmin = uint8(_settings >> 200);
        bool _isAdmin = isAdmin == 0 ? false : true;
        Settings settings = Settings.wrap(_settings);
        assertEq(settings.isAdmin(), _isAdmin);
    }

    function test_isAdmin_ignoresUpperBytes() public pure {
        Settings settings = Settings.wrap(0xFFFFFFFFFFFF0000000000000000000000000000000000000000000000000000);
        assertEq(settings.isAdmin(), false);
    }

    function test_isAdmin_returnsTrueDirtyUpperBits() public pure {
        Settings settings = Settings.wrap(0xFFFFFFFFFFFFE000000000000000000000000000000000000000000000000000);
        assertEq(settings.isAdmin(), true);
    }

    function test_isAdmin_returnsTrueIfSet() public pure {
        Settings settings = Settings.wrap(0xFFFFFFFFFFFFFF00000000000000000000000000000000000000000000000000);
        assertEq(settings.isAdmin(), true);
    }

    function test_hook() public pure {
        IHook hook = IHook(address(1));
        Settings settings = SettingsBuilder.init().fromHook(hook);
        assertEq(address(settings.hook()), address(hook));
    }

    function test_hook_fuzz(IHook hook) public pure {
        Settings settings = SettingsBuilder.init().fromHook(hook);
        assertEq(address(settings.hook()), address(hook));
    }

    function test_isExpired_expiryOfZero_isNotExpired() public {
        Settings settings = SettingsBuilder.init().fromExpiration(0);
        vm.warp(1);
        (bool expired, uint40 expiry) = settings.isExpired();
        assertEq(expired, false);
        assertEq(expiry, 0);
    }

    function test_isExpired_fuzz(uint40 expiration) public {
        vm.assume(expiration > 0 && expiration < type(uint40).max);
        Settings settings = SettingsBuilder.init().fromExpiration(expiration);
        vm.warp(expiration + 1);
        (bool expired, uint40 expiry) = settings.isExpired();
        assertEq(expired, true);
        assertEq(expiry, expiration);
    }

    function test_isExpired_equalToBlockTimeStamp_isNotExpired() public {
        vm.warp(10); // don't use 0 since it is special cased
        Settings settings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp));
        (bool expired, uint40 expiry) = settings.isExpired();
        assertEq(expired, false);
        assertEq(expiry, block.timestamp);
    }
}
