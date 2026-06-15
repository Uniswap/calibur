// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {HookHandler} from "./utils/HookHandler.sol";
import {Key, KeyType, KeyLib} from "../src/libraries/KeyLib.sol";
import {IERC7821} from "../src/interfaces/IERC7821.sol";
import {IKeyManagement} from "../src/interfaces/IKeyManagement.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IERC4337Account} from "../src/ERC4337Account.sol";
import {TestKey, TestKeyManager} from "./utils/TestKeyManager.sol";
import {Settings, SettingsLib} from "../src/libraries/SettingsLib.sol";
import {SettingsBuilder} from "./utils/SettingsBuilder.sol";
import {Constants} from "./utils/Constants.sol";
import {BaseAuthorization} from "../src/BaseAuthorization.sol";
import {IHook} from "../src/interfaces/IHook.sol";
import {HooksLib} from "../src/libraries/HooksLib.sol";
import {MockHook} from "./utils/MockHook.sol";

contract CaliburTest is DelegationHandler, HookHandler {
    using KeyLib for Key;
    using TestKeyManager for TestKey;
    using SettingsLib for Settings;
    using SettingsBuilder for Settings;

    event Registered(bytes32 indexed keyHash, Key key);
    event Revoked(bytes32 indexed keyHash);
    event KeySettingsUpdated(bytes32 indexed keyHash, Settings settings);

    function setUp() public {
        setUpDelegation();
        setUpHooks();
    }

    function test_signerAccount_codeSize() public view {
        // length of the code is 23 as specified by ERC-7702
        assertEq(address(signerAccount).code.length, 0x17);
    }

    function test_caliburEntry_codeSize() public {
        vm.snapshotValue("caliburEntry bytecode size", address(calibur).code.length);
    }

    function test_namespaceAndVersion() public view {
        assertEq(signerAccount.namespaceAndVersion(), "Uniswap.Calibur.1.0.0");
    }

    function test_entrypoint_gas() public {
        signerAccount.ENTRY_POINT();
        vm.snapshotGasLastCall("entrypoint");
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
        assertEq(keySettings.isAdmin(), false);
        assertEq(uint256(fetchedKey.keyType), uint256(KeyType.Secp256k1));
        assertEq(fetchedKey.publicKey, abi.encode(mockSecp256k1PublicKey));
        assertEq(signerAccount.keyCount(), 1);
    }

    function test_register_revertsWithUnauthorized() public {
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.register(mockSecp256k1Key);
    }

    function testFuzz_register_revertsForOversizedSecp256k1Key(address addr, uint8 extra) public {
        // address(this) decodes to the root key, which is rejected by a separate check
        vm.assume(addr != address(0) && addr != address(signerAccount) && extra != 0);
        // Trailing bytes produce a distinct keyHash that still verifies the same signer
        Key memory aliasKey = Key(KeyType.Secp256k1, abi.encodePacked(abi.encode(addr), new bytes(extra)));
        vm.prank(address(signerAccount));
        vm.expectRevert(IKeyManagement.InvalidKey.selector);
        signerAccount.register(aliasKey);
    }

    function test_register_revertsForZeroAddressSecp256k1Key() public {
        Key memory zeroKey = Key(KeyType.Secp256k1, abi.encode(address(0)));
        vm.prank(address(signerAccount));
        vm.expectRevert(IKeyManagement.InvalidKey.selector);
        signerAccount.register(zeroKey);
    }

    function testFuzz_register_revertsForWrongLengthP256Key(uint256 x, uint256 y, uint8 extra) public {
        vm.assume(extra != 0);
        bytes memory publicKey = abi.encodePacked(abi.encode(x, y), new bytes(extra));
        vm.startPrank(address(signerAccount));
        vm.expectRevert(IKeyManagement.InvalidKey.selector);
        signerAccount.register(Key(KeyType.P256, publicKey));
        vm.expectRevert(IKeyManagement.InvalidKey.selector);
        signerAccount.register(Key(KeyType.WebAuthnP256, publicKey));
        vm.stopPrank();
    }

    function test_register_revertsWhenKeyIsDefaultEntryPoint() public {
        Key memory entryPointKey = Key(KeyType.Secp256k1, abi.encode(signerAccount.ENTRY_POINT()));
        vm.prank(address(signerAccount));
        vm.expectRevert(abi.encodeWithSelector(IKeyManagement.CannotRegisterKey.selector, entryPointKey));
        signerAccount.register(entryPointKey);
    }

    function testFuzz_register_revertsWhenKeyIsEntryPoint(address entryPoint) public {
        // The root key is rejected by a different check, so exclude it here
        vm.assume(entryPoint != address(signerAccount) && entryPoint != address(0));
        vm.startPrank(address(signerAccount));
        signerAccount.updateEntryPoint(entryPoint);

        // A Secp256k1 key for the configured EntryPoint collides with the caller key it would derive,
        // so registration must be rejected
        Key memory entryPointKey = Key(KeyType.Secp256k1, abi.encode(entryPoint));
        vm.expectRevert(abi.encodeWithSelector(IKeyManagement.CannotRegisterKey.selector, entryPointKey));
        signerAccount.register(entryPointKey);
        vm.stopPrank();
    }

    function test_register_revertsWhenKeyIsSenderCreator() public {
        address senderCreator = address(IEntryPoint(signerAccount.ENTRY_POINT()).senderCreator());
        Key memory senderCreatorKey = Key(KeyType.Secp256k1, abi.encode(senderCreator));
        vm.prank(address(signerAccount));
        vm.expectRevert(abi.encodeWithSelector(IKeyManagement.CannotRegisterKey.selector, senderCreatorKey));
        signerAccount.register(senderCreatorKey);
    }

    function test_register_expiryUpdated() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Key memory fetchedKey = signerAccount.getKey(keyHash);
        Settings keySettings = signerAccount.getKeySettings(keyHash);
        assertEq(keySettings.expiration(), 0);
        assertEq(keySettings.isAdmin(), false);
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
        assertEq(fetchedKeySettings.isAdmin(), false);
        assertEq(uint256(fetchedKey.keyType), uint256(KeyType.Secp256k1));
        assertEq(fetchedKey.publicKey, abi.encode(mockSecp256k1PublicKey));
        // key count should remain the same
        assertEq(signerAccount.keyCount(), 1);
    }

    function test_update_revertsWithUnauthorized() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
        signerAccount.update(keyHash, mockSecp256k1KeySettings);
    }

    function test_update_revertsWithCannotUpdateRootKey() public {
        vm.expectRevert(IKeyManagement.CannotUpdateRootKey.selector);
        vm.prank(address(signerAccount));
        signerAccount.update(KeyLib.ROOT_KEY_HASH, SettingsBuilder.init());
    }

    function test_update_expiryUpdated() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Settings keySettings = signerAccount.getKeySettings(keyHash);
        assertEq(keySettings.expiration(), 0);
        assertEq(keySettings.isAdmin(), false);

        keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp + 3600));

        vm.expectEmit(true, false, false, true);
        emit KeySettingsUpdated(keyHash, keySettings);
        signerAccount.update(keyHash, keySettings);

        keySettings = signerAccount.getKeySettings(keyHash);
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        assertEq(keySettings.isAdmin(), false);

        vm.stopPrank();
    }

    function test_update_adminUpdated() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Settings keySettings = signerAccount.getKeySettings(keyHash);
        assertEq(keySettings.isAdmin(), false);

        keySettings = SettingsBuilder.init().fromIsAdmin(true);

        vm.expectEmit(true, false, false, true);
        emit KeySettingsUpdated(keyHash, keySettings);
        signerAccount.update(keyHash, keySettings);

        keySettings = signerAccount.getKeySettings(keyHash);
        assertEq(keySettings.isAdmin(), true);

        vm.stopPrank();
    }

    function testFuzz_update_revertsWhenReservedBitsDirty(uint56 reservedBits, uint40 expiration, bool isAdmin) public {
        // Bits 201-255 sit above the admin flag (bit 200) and must be zero
        uint256 dirtyBits = uint256(reservedBits) << 201;
        vm.assume(dirtyBits != 0);
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Settings settings = SettingsBuilder.init().fromExpiration(expiration).fromIsAdmin(isAdmin);
        // Set reserved bits above the admin flag on top of an otherwise valid value
        Settings dirty = Settings.wrap(Settings.unwrap(settings) | dirtyBits);

        vm.expectRevert(IKeyManagement.InvalidSettings.selector);
        signerAccount.update(keyHash, dirty);
        vm.stopPrank();
    }

    function test_update_revertsWhen48BitValidUntilSpillsIntoAdmin() public {
        // A uint48 ERC-4337 validUntil value shifted by 160 occupies bits 160-207. The low 40 bits land in
        // expiration; the high 8 bits land in the admin byte. type(uint48).max << 160 would otherwise be read
        // as expiration = type(uint40).max and isAdmin = true. update must reject it.
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Settings spilled = Settings.wrap(uint256(type(uint48).max) << 160);
        assertEq(spilled.isAdmin(), true);

        vm.expectRevert(IKeyManagement.InvalidSettings.selector);
        signerAccount.update(keyHash, spilled);
        vm.stopPrank();
    }

    function testFuzz_update_revertsWhenAdminByteNotZeroOrOne(uint8 adminByte, uint40 expiration) public {
        // Only bit 200 may be set in the admin byte; any value above 1 spills into the reserved region
        vm.assume(adminByte > 1);
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        Settings dirty = Settings.wrap(
            (Settings.unwrap(SettingsBuilder.init().fromExpiration(expiration))) | (uint256(adminByte) << 200)
        );

        vm.expectRevert(IKeyManagement.InvalidSettings.selector);
        signerAccount.update(keyHash, dirty);
        vm.stopPrank();
    }

    function testFuzz_update_succeedsWhenReservedBitsUnset(uint40 expiration, bool isAdmin) public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        // Use a valid hook (code + flags) so the update passes hook validation; the focus here is
        // that clean reserved bits round-trip exactly across the used fields.
        Settings settings =
            SettingsBuilder.init().fromExpiration(expiration).fromIsAdmin(isAdmin).fromHook(IHook(address(mockHook)));
        signerAccount.update(keyHash, settings);

        // Settings with clean reserved bits must round-trip exactly: the check must not touch used fields
        assertEq(Settings.unwrap(signerAccount.getKeySettings(keyHash)), Settings.unwrap(settings));
        vm.stopPrank();
    }

    function test_update_revertsWhenHookHasCodeButNoFlags() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        // noHooks (0xC0..00) has code etched but no flag bits set, so no callback would ever fire
        vm.expectRevert(IKeyManagement.InvalidHook.selector);
        signerAccount.update(keyHash, SettingsBuilder.init().fromHook(IHook(address(noHooks))));
        vm.stopPrank();
    }

    function test_update_revertsWhenHookHasFlagsButNoCode() public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        // BEFORE_EXECUTE_FLAG (0x08) set but nothing deployed at the address
        address hookAddr = 0xc000000000000000000000000000000000000008;
        assertEq(hookAddr.code.length, 0);

        vm.expectRevert(IKeyManagement.InvalidHook.selector);
        signerAccount.update(keyHash, SettingsBuilder.init().fromHook(IHook(hookAddr)));
        vm.stopPrank();
    }

    /// @dev A hook is accepted iff it has both code and at least one flag; vary only the
    ///      flag-bearing low byte (base 0xC0.. avoids precompiles) with code always present.
    /// forge-config: default.fuzz.runs = 256
    function testFuzz_update_hookFlagValidation(uint8 lowByte) public {
        bytes32 keyHash = mockSecp256k1Key.hash();
        vm.startPrank(address(signerAccount));
        signerAccount.register(mockSecp256k1Key);

        address hookAddr = address(uint160(0xC000000000000000000000000000000000000000) | uint160(lowByte));
        vm.etch(hookAddr, address(new MockHook()).code);

        Settings keySettings = SettingsBuilder.init().fromHook(IHook(hookAddr));

        if (uint160(hookAddr) & HooksLib.ALL_FLAGS == 0) {
            vm.expectRevert(IKeyManagement.InvalidHook.selector);
            signerAccount.update(keyHash, keySettings);
        } else {
            signerAccount.update(keyHash, keySettings);
            assertEq(address(signerAccount.getKeySettings(keyHash).hook()), hookAddr);
        }
        vm.stopPrank();
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
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
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
        Key memory _mockKey;
        string memory _publicKey = "";
        address _mockPublicKey;
        for (uint256 i = 0; i < numKeys; i++) {
            _mockPublicKey = makeAddr(string(abi.encodePacked(_publicKey, i)));
            _mockKey = Key(KeyType.Secp256k1, abi.encode(_mockPublicKey));
            vm.prank(address(signerAccount));
            signerAccount.register(_mockKey);
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
        assertEq(keySettings.isAdmin(), false);
        assertEq(uint256(key.keyType), uint256(KeyType.Secp256k1));
        assertEq(key.publicKey, abi.encode(mockSecp256k1PublicKey));

        key = signerAccount.keyAt(1);
        keySettings = signerAccount.getKeySettings(key.hash());
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        assertEq(keySettings.isAdmin(), false);
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
        assertEq(keySettings.isAdmin(), false);
        assertEq(uint256(key.keyType), uint256(KeyType.Secp256k1));
        assertEq(key.publicKey, abi.encode(mockSecp256k1PublicKey2));

        // only one key should be left
        assertEq(signerAccount.keyCount(), 1);
    }

    function test_getKey_returnsRootKey() public view {
        Key memory key = signerAccount.getKey(KeyLib.ROOT_KEY_HASH);
        assertEq(uint256(key.keyType), uint256(KeyType.Secp256k1));
        assertEq(key.publicKey, abi.encode(address(signerAccount)));
    }

    function test_getKey_returnsRegisteredKey() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        Key memory key = signerAccount.getKey(p256Key.toKeyHash());
        assertEq(uint256(key.keyType), uint256(KeyType.P256));
        assertEq(key.publicKey, p256Key.publicKey);
    }

    function test_getKey_reverts_withKeyDoesNotExist() public {
        bytes32 keyHash = keccak256("does not exist");
        vm.expectRevert(IKeyManagement.KeyDoesNotExist.selector);
        signerAccount.getKey(keyHash);
    }

    function test_getKeySettings_returnsRootSettings() public view {
        Settings keySettings = signerAccount.getKeySettings(KeyLib.ROOT_KEY_HASH);
        assertEq(Settings.unwrap(keySettings), Settings.unwrap(SettingsLib.ROOT_KEY_SETTINGS));
        assertEq(keySettings.isAdmin(), true);
        assertEq(keySettings.expiration(), 0);
        assertEq(address(keySettings.hook()), address(0));
    }

    function test_getKeySettings_returnsRegisteredKeySettings() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        Settings keySettings = signerAccount.getKeySettings(p256Key.toKeyHash());
        // Expect default settings
        assertEq(keySettings.expiration(), 0);
        assertEq(keySettings.isAdmin(), false);
        assertEq(address(keySettings.hook()), address(0));

        // Update settings
        keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp + 3600));
        vm.prank(address(signerAccount));
        signerAccount.update(p256Key.toKeyHash(), keySettings);

        keySettings = signerAccount.getKeySettings(p256Key.toKeyHash());
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        assertEq(keySettings.isAdmin(), false);
        assertEq(address(keySettings.hook()), address(0));
    }

    function test_getKeySettings_reverts_withKeyDoesNotExist() public {
        bytes32 keyHash = keccak256("does not exist");
        vm.expectRevert(IKeyManagement.KeyDoesNotExist.selector);
        signerAccount.getKeySettings(keyHash);
    }

    function test_entryPoint_defaultValue() public view {
        assertEq(signerAccount.ENTRY_POINT(), Constants.ENTRY_POINT_V_0_8);
    }

    function test_updateEntryPoint_revertsWithUnauthorized() public {
        vm.expectRevert(BaseAuthorization.Unauthorized.selector);
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

    function test_validateUserOp_rawSignature_withRootKey_succeeds() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes memory signature = signerTestKey.sign(userOpHash);
        userOp.signature = signature;

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0);
    }

    function test_validateUserOp_rawSignature_withRootKey_wrongDigest_returnsInvalidSignature() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes32 wrongUserOpHash = keccak256("invalid");
        bytes memory signature = signerTestKey.sign(wrongUserOpHash);
        userOp.signature = signature;

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 1);
    }

    function test_validateUserOp_rawSignature_withNonRootKey_returnsInvalidSignature() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        TestKey memory p256Key = TestKeyManager.withSeed(KeyType.P256, 1234);
        bytes memory signature = p256Key.sign(userOpHash);
        userOp.signature = signature;

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 1);
    }

    function test_validateUserOp_wrappedSignature_withRootKey_succeeds() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes memory signature = signerTestKey.sign(userOpHash);
        // No hook data for root key
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 0);
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
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        // 0 is valid
        assertEq(validationData, uint256(block.timestamp + 3600) << 160 | 0);
    }

    /// @dev Because the signature is invalid, we do not pack the validUntil value
    function test_validateUserOp_invalidSignature_doesNotPackValidUntil() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.startPrank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp + 3600));
        assertEq(keySettings.expiration(), uint40(block.timestamp + 3600));
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        // Sign with an incorrect private key for the claimed keyHash
        TestKey memory otherP256Key = TestKeyManager.withSeed(KeyType.P256, 1234);
        bytes memory signature = otherP256Key.sign(userOpHash);
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, 1);
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
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

        vm.prank(address(entryPoint));
        uint256 validationData = signerAccount.validateUserOp(userOp, userOpHash, 0);
        // Expect that the validation data contains the expiration + that the signature is valid
        assertEq(validationData, uint256(keySettings.expiration()) << 160 | 0);
    }

    function test_validateUserOp_missingAccountFunds() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        uint256 missingAccountFunds = 1e18;
        bytes memory signature = signerTestKey.sign(userOpHash);
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

        deal(address(signerAccount), 1e18);

        uint256 beforeDeposit = entryPoint.getDepositInfo(address(signerAccount)).deposit;

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, missingAccountFunds);

        assertEq(valid, 0); // 0 is valid

        // account sent in 1e18 to the entry point and their deposit was updated
        assertEq(address(signerAccount).balance, 0);
        assertEq(entryPoint.getDepositInfo(address(signerAccount)).deposit, beforeDeposit + 1e18);
    }

    function test_validateUserOp_withHook_reverts() public {
        bytes32 validUserOpHash = keccak256("valid");
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        bytes memory signature = p256Key.sign(validUserOpHash);

        vm.startPrank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromHook(mockHook);
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        // Spoofed signature and userOpHash
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;
        bytes32 userOpHash = validUserOpHash;

        mockHook.setValidateUserOpReturnValue(false);

        vm.startPrank(address(entryPoint));
        vm.expectRevert();
        signerAccount.validateUserOp(userOp, userOpHash, 0);
        vm.stopPrank();
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
        userOp.signature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);

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
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

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
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

        deal(address(signerAccount), 1e18);

        vm.prank(address(entryPoint));
        signerAccount.validateUserOp(userOp, userOpHash, missingAccountFunds);
        vm.snapshotGasLastCall("validateUserOp_missingAccountFunds");
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_validateUserOp_withHook_validSignature_gas() public {
        bytes32 validUserOpHash = keccak256("valid");
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        bytes memory signature = p256Key.sign(validUserOpHash);

        vm.startPrank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromHook(mockHook);
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        // Spoofed signature and userOpHash
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;
        bytes32 userOpHash = validUserOpHash;

        mockHook.setValidateUserOpReturnValue(true);

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, 0);
        vm.snapshotGasLastCall("validateUserOp_withHook_validSignature");
        assertEq(valid, 0);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_validateUserOp_withHook_invalidSignature_gas() public {
        bytes32 validUserOpHash = keccak256("valid");
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        bytes memory signature = p256Key.sign(keccak256("invalid"));

        vm.startPrank(address(signerAccount));
        Settings keySettings = SettingsBuilder.init().fromHook(mockHook);
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        PackedUserOperation memory userOp;
        // Spoofed signature and userOpHash
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;
        bytes32 userOpHash = validUserOpHash;

        // Hook returns 0 for valid signature, expect that this value is not used since the signature is invalid
        mockHook.setValidateUserOpReturnValue(true);

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, 0);
        vm.snapshotGasLastCall("validateUserOp_withHook_invalidSignature");
        assertEq(valid, 1);
    }

    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_validateUserOp_invalidSignature_gas() public {
        PackedUserOperation memory userOp;
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        // incorrect private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1234, userOpHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        userOp.signature = wrappedSignature;

        vm.prank(address(entryPoint));
        uint256 valid = signerAccount.validateUserOp(userOp, userOpHash, 0);
        vm.snapshotGasLastCall("validateUserOp_invalidSignature");
        assertEq(valid, 1); // 1 is invalid
    }
}
