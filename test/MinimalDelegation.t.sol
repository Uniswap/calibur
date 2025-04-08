// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {HookHandler} from "./utils/HookHandler.sol";
import {Key, KeyType, KeyLib} from "../src/libraries/KeyLib.sol";
import {IERC7821} from "../src/interfaces/IERC7821.sol";
import {IKeyManagement} from "../src/interfaces/IKeyManagement.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IERC4337Account} from "../src/ERC4337Account.sol";
import {TestKey, TestKeyManager} from "./utils/TestKeyManager.sol";
import {Settings, SettingsLib} from "../src/libraries/SettingsLib.sol";
import {SettingsBuilder} from "./utils/SettingsBuilder.sol";
import {Constants} from "./utils/Constants.sol";

contract MinimalDelegationTest is DelegationHandler, HookHandler {
    using KeyLib for Key;
    using TestKeyManager for TestKey;
    using SettingsLib for Settings;
    using SettingsBuilder for Settings;

    event Registered(bytes32 indexed keyHash, Key key);
    event Revoked(bytes32 indexed keyHash);

    function setUp() public {
        setUpDelegation();
        setUpHooks();
    }

    function test_signerAccount_codeSize() public view {
        // length of the code is 23 as specified by ERC-7702
        assertEq(address(signerAccount).code.length, 0x17);
    }

    function test_minimalDelegationEntry_codeSize() public {
        vm.snapshotValue("minimalDelegationEntry bytecode size", address(minimalDelegation).code.length);
    }

    function test_register() public {
        bytes32 keyHash = mockSecp256k1Key.hash();

        vm.expectEmit(true, false, false, true);
        emit Registered(keyHash, mockSecp256k1Key);

        vm.prank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Key memory fetchedKey = signerAccount.getKey(keyHash);
        Settings keySettings = signerAccount.getKeySettings(keyHash);
        assertEq(keySettings.expiration(), 0);
        assertEq(uint256(fetchedKey.keyType), uint256(KeyType.Secp256k1));
        assertEq(fetchedKey.publicKey, abi.encode(mockSecp256k1PublicKey));
        assertEq(signerAccount.keyCount(), 1);
    }

    function test_register_revertsWithUnauthorized() public {
        vm.expectRevert(IERC7821.Unauthorized.selector);
        signerAccount.register(mockSecp256k1Key);
    }

    function test_register_expiryUpdated() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Key memory fetchedKey = signerAccount.getKey(keyHash);
        Settings keySettings = signerAccount.getKeySettings(keyHash);
        assertEq(keySettings.expiration(), 0);
        assertEq(uint256(fetchedKey.keyType), uint256(KeyType.Secp256k1));
        assertEq(fetchedKey.publicKey, abi.encode(mockSecp256k1PublicKey));
        assertEq(signerAccount.keyCount(), 1);

        vm.warp(100);
        keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp + 3600));
        // already registered key should be updated
        signerAccount.update(keyHash, keySettings);

        fetchedKey = signerAccount.getKey(keyHash);
        Settings fetchedKeySettings = signerAccount.getKeySettings(keyHash);
        assertEq(fetchedKeySettings.expiration(), uint40(block.timestamp + 3600));
        assertEq(uint256(fetchedKey.keyType), uint256(KeyType.Secp256k1));
        assertEq(fetchedKey.publicKey, abi.encode(mockSecp256k1PublicKey));
        // key count should remain the same
        assertEq(signerAccount.keyCount(), 1);
    }

    function test_revoke() public {
        // first register the key
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);
        assertEq(signerAccount.keyCount(), 1);

        bytes32 keyHash = mockSecp256k1Key.hash();

        vm.expectEmit(true, false, false, true);
        emit Revoked(keyHash);

        // then revoke the key
        signerAccount.revoke(keyHash);

        // then expect the key to not exist
        vm.expectRevert(IKeyManagement.KeyDoesNotExist.selector);
        signerAccount.getKey(keyHash);
        assertEq(signerAccount.keyCount(), 0);
    }

    function test_revoke_revertsWithUnauthorized() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.expectRevert(IERC7821.Unauthorized.selector);
        signerAccount.revoke(keyHash);
    }

    function test_revoke_revertsWithKeyDoesNotExist() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.expectRevert(IKeyManagement.KeyDoesNotExist.selector);
        vm.prank(address(signerAccount));
        signerAccount.revoke(keyHash);
    }

    function test_keyCount() public {
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);
        signerAccount.register(mockSecp256k1Key2);

        assertEq(signerAccount.keyCount(), 2);
    }

    /// forge-config: default.fuzz.runs = 100
    /// forge-config: ci.fuzz.runs = 500
    function test_fuzz_keyCount(uint8 numKeys) public {
        Key memory mockSecp256k1Key;
        string memory publicKey = "";
        address mockSecp256k1PublicKey;
        for (uint256 i = 0; i < numKeys; i++) {
            mockSecp256k1PublicKey = makeAddr(string(abi.encodePacked(publicKey, i)));
            mockSecp256k1Key = Key(KeyType.Secp256k1, abi.encode(mockSecp256k1PublicKey));
            vm.prank(address(signerAccount));
            signerAccount.register(mockSecp256k1Key);
        }

        assertEq(signerAccount.keyCount(), numKeys);
    }

    function test_keyAt() public {
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);
        signerAccount.update(mockSecp256k1Key.hash(), mockSecp256k1KeySettings);
        signerAccount.register(mockSecp256k1Key2);
        signerAccount.update(mockSecp256k1Key2.hash(), mockSecp256k1Key2Settings);

        // 2 keys registered
        assertEq(signerAccount.keyCount(), 2);

        Key memory key = signerAccount.keyAt(0);
        Settings keySettings = signerAccount.getKeySettings(key.hash());
        assertEq(keySettings.expiration(), 0);
        assertEq(uint256(key.keyType), uint256(KeyType.Secp256k1));
        assertEq(key.publicKey, abi.encode(mockSecp256k1PublicKey));

        key = signerAccount.keyAt(1);
        keySettings = signerAccount.getKeySettings(key.hash());
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        assertEq(uint256(key.keyType), uint256(KeyType.Secp256k1));
        assertEq(key.publicKey, abi.encode(mockSecp256k1PublicKey2));

        // revoke first key
        signerAccount.revoke(mockSecp256k1Key.hash());
        // indexes should be shifted
        vm.expectRevert();
        signerAccount.keyAt(1);

        key = signerAccount.keyAt(0);
        keySettings = signerAccount.getKeySettings(key.hash());
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        assertEq(uint256(key.keyType), uint256(KeyType.Secp256k1));
        assertEq(key.publicKey, abi.encode(mockSecp256k1PublicKey2));

        // only one key should be left
        assertEq(signerAccount.keyCount(), 1);
    }

    function test_entryPoint_defaultValue() public view {
        assertEq(signerAccount.ENTRY_POINT(), Constants.ENTRY_POINT_V_0_8);
    }

    function test_updateEntryPoint_revertsWithUnauthorized() public {
        vm.expectRevert(IERC7821.Unauthorized.selector);
        signerAccount.updateEntryPoint(address(entryPoint));
    }

    function test_updateEntryPoint_succeeds() public {
        address newEntryPoint = makeAddr("newEntryPoint");

        vm.prank(address(signerAccount));
        signerAccount.updateEntryPoint(newEntryPoint);

        assertEq(signerAccount.ENTRY_POINT(), newEntryPoint);
    }

    function test_updateEntryPoint_fuzz(address newEntryPoint) public {
        vm.prank(address(signerAccount));
        signerAccount.updateEntryPoint(newEntryPoint);

        assertEq(signerAccount.ENTRY_POINT(), newEntryPoint);
    }

    function test_validateUserOp_validSignature_withExpiration() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp + 3600));
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes memory signature = p256Key.sign(userOpHash);
        userOp.signature = abi.encode(p256Key.toKeyHash(), signature);

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        // 0 is valid
        assertEq(validationData, uint256(block.timestamp + 3600) << 160 | 0);
    }

    function test_validateUserOp_invalidSignature_withExpiration() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp + 3600));
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        // incorrect private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1234, userOpHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        userOp.signature = abi.encode(p256Key.toKeyHash(), signature);

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        // 1 is invalid
        assertEq(validationData, uint256(block.timestamp + 3600) << 160 | 1);
    }

    function test_validateUserOp_withHook_validSignature() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        bytes memory signature = p256Key.sign(KeyLib.ROOT_KEY_HASH);

        vm.startPrank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromHook(mockHook);
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        // Spoofed signature and userOpHash
        userOp.signature = abi.encode(p256Key.toKeyHash(), signature);
        bytes32 userOpHash = KeyLib.ROOT_KEY_HASH;

        mockHook.setValidateUserOpReturnValue(0);

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, 0);
        assertEq(valid, 0);
    }

    function test_validateUserOp_expiredKey() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signerAccount));
        vm.warp(100);
        Settings keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp - 1));
        assertEq(keySettings.expiration(), uint40(block.timestamp - 1));
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes memory signature = p256Key.sign(userOpHash);
        userOp.signature = abi.encode(p256Key.toKeyHash(), signature);

        vm.prank(address(entryPoint));
        vm.expectRevert(abi.encodeWithSelector(IKeyManagement.KeyExpired.selector, uint40(block.timestamp - 1)));
        signerAccount.validateUserOp(userOp, userOpHash, 0);
    }

    function test_validateUserOp_invalidSignature() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        // incorrect private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1234, userOpHash);
        userOp.signature = abi.encode(KeyLib.ROOT_KEY_HASH, abi.encodePacked(r, s, v));

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, 0);
        assertEq(valid, 1); // 1 is invalid
    }

    function test_validateUserOp_missingAccountFunds() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        uint256 missingAccountFunds = 1e18;
        userOp.signature = abi.encode(KeyLib.ROOT_KEY_HASH, signerTestKey.sign(userOpHash));

        deal(address(signerAccount), 1e18);

        uint256 beforeDeposit = entryPoint.getDepositInfo(address(signerAccount)).deposit;

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, missingAccountFunds);

        assertEq(valid, 0); // 0 is valid

        // account sent in 1e18 to the entry point and their deposit was updated
        assertEq(address(signerAccount).balance, 0);
        assertEq(entryPoint.getDepositInfo(address(signerAccount)).deposit, beforeDeposit + 1e18);
    }

    /// GAS TESTS

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_register_gas() public {
        bytes32 keyHash = mockSecp256k1Key.hash();

        vm.expectEmit(true, false, false, true);
        emit Registered(keyHash, mockSecp256k1Key);

        vm.prank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);
        vm.snapshotGasLastCall("register");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_revoke_gas() public {
        // first register the key
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);
        bytes32 keyHash = mockSecp256k1Key.hash();
        assertEq(signerAccount.keyCount(), 1);

        vm.expectEmit(true, false, false, true);
        emit Revoked(keyHash);

        // then revoke the key
        signerAccount.revoke(keyHash);
        vm.snapshotGasLastCall("revoke");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_validateUserOp_validSignature() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes memory signature = signerTestKey.sign(userOpHash);
        userOp.signature = abi.encode(KeyLib.ROOT_KEY_HASH, signature);

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, 0);
        vm.snapshotGasLastCall("validateUserOp_no_missingAccountFunds");
        assertEq(valid, 0); // 0 is valid
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_validateUserOp_validSignature_gas() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes memory signature = signerTestKey.sign(userOpHash);
        userOp.signature = abi.encode(KeyLib.ROOT_KEY_HASH, signature);

        vm.prank(address(entryPoint));
        signerAccount.validateUserOp(userOp, userOpHash, 0);
        vm.snapshotGasLastCall("validateUserOp_no_missingAccountFunds");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_validateUserOp_missingAccountFunds_gas() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        uint256 missingAccountFunds = 1e18;
        bytes memory signature = signerTestKey.sign(userOpHash);
        userOp.signature = abi.encode(KeyLib.ROOT_KEY_HASH, signature);

        deal(address(signerAccount), 1e18);

        vm.prank(address(entryPoint));
        signerAccount.validateUserOp(userOp, userOpHash, missingAccountFunds);
        vm.snapshotGasLastCall("validateUserOp_missingAccountFunds");
    }
}
