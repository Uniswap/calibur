// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {HookHandler} from "./utils/HookHandler.sol";
import {ERC1271Handler} from "./utils/ERC1271Handler.sol";
import {KeyType} from "../src/libraries/KeyLib.sol";
import {TestKeyManager, TestKey} from "./utils/TestKeyManager.sol";
import {TestKeyManager} from "./utils/TestKeyManager.sol";
import {Settings, SettingsLib} from "../src/libraries/SettingsLib.sol";
import {SettingsBuilder} from "./utils/SettingsBuilder.sol";
import {IValidationHook} from "../src/interfaces/IValidationHook.sol";
import {IKeyManagement} from "../src/interfaces/IKeyManagement.sol";
import {IERC1271} from "../src/interfaces/IERC1271.sol";
import {KeyLib} from "../src/libraries/KeyLib.sol";
import {TypedDataSignBuilder} from "./utils/TypedDataSignBuilder.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract CaliburIsValidSignatureTest is DelegationHandler, HookHandler, ERC1271Handler {
    using TestKeyManager for TestKey;
    using SettingsBuilder for Settings;
    using TypedDataSignBuilder for *;

    error SliceOutOfBounds();

    bytes4 private constant _1271_MAGIC_VALUE = 0x1626ba7e;
    bytes4 private constant _1271_INVALID_VALUE = 0xffffffff;
    bytes4 private constant _ERC7739_MAGIC_VALUE = 0x77390001;
    bytes32 private constant _ERC7739_HASH = 0x7739773977397739773977397739773977397739773977397739773977397739;

    // Test hashed TypedDataSign digest
    bytes32 TEST_TYPED_DATA_SIGN_DIGEST;

    function setUp() public {
        setUpDelegation();
        setUpHooks();
        // Set after delegation
        bytes memory signerAccountDomainBytes = IERC5267(address(signerAccount)).toDomainBytes();
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        TEST_TYPED_DATA_SIGN_DIGEST =
            contentsHash.hashTypedDataSign(signerAccountDomainBytes, appDomainSeparator, contentsName, contentsType);
    }

    /**
     *
     * MARK: ERC7739 sentinel value test
     *
     */
    function test_isValidSignature_ERC7739_magicValue() public view {
        bytes4 result = signerAccount.isValidSignature(_ERC7739_HASH, "");
        assertEq(result, _ERC7739_MAGIC_VALUE);
    }

    /**
     *
     * MARK: Valid signature tests
     *
     */

    /**
     * Scenario: Root key
     * 1. 65 byte signature from the root key
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_rootKey_rawSignature_isValid_gas() public {
        bytes32 digest = keccak256("test");
        // Sign the digest
        bytes memory signature = signerTestKey.sign(digest);
        // Since signature length is 65, it should use raw ECDSA recover
        bytes4 result = signerAccount.isValidSignature(digest, signature);
        vm.snapshotGasLastCall("isValidSignature_rootKey_rawSignature");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: Root key
     * 1. 64 byte compact signature from the root key
     * = valid signature
     */
    function test_isValidSignature_rootKey_compactSignature_isValid_gas() public {
        bytes32 digest = keccak256("test");
        (bytes32 r, bytes32 vs) = vm.signCompact(signerTestKey.privateKey, digest);
        bytes memory signature = abi.encodePacked(r, vs);
        bytes4 result = signerAccount.isValidSignature(digest, signature);
        vm.snapshotGasLastCall("isValidSignature_rootKey_compactSignature");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: Root key
     * 1. Not raw signature
     * 2. Typed data sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_rootKey_wrappedSignature___typedDataSign_isValid_gas() public {
        bytes memory signature = signerTestKey.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, typedDataSignSignature, EMPTY_HOOK_DATA);
        // ensure the call returns the ERC1271 magic value
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(digest, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_rootKey_wrappedSignature___typedDataSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: Non root Secp256k1 key
     * 1. Not raw signature
     * 2. Typed data sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_secp256k1_wrappedSignature___typedDataSign_isValid_gas() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, 0xb0b);
        vm.prank(address(signer));
        signerAccount.register(key.toKey());

        bytes memory signature = key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(digest, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_secp256k1_wrappedSignature___typedDataSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: P256 key
     * 1. Not raw signature
     * 2. Typed data sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_P256_wrappedSignature___typedDataSign_isValid_gas() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signer));
        signerAccount.register(p256Key.toKey());

        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory signature = p256Key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        // Digest is what is calculated by the ERC1271 contract which hashes its domain separator to the contents hash
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(digest, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_P256_wrappedSignature___typedDataSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: WebAuthnP256 key
     * 1. Not raw signature
     * 2. Typed data sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_WebAuthnP256_wrappedSignature___typedDataSign_isValid_gas() public {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);

        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory signature = webAuthnP256Key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(webAuthnP256Key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        vm.prank(address(signer));
        signerAccount.register(webAuthnP256Key.toKey());

        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(digest, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_WebAuthnP256_wrappedSignature___typedDataSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: P256 key with hook
     * 1. Not raw signature
     * 2. Typed data sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_P256_wrappedSignature___typedDataSign_withHook_isValid_gas() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        bytes32 keyHash = p256Key.toKeyHash();

        vm.startPrank(address(signerAccount));
        signerAccount.register(p256Key.toKey());
        signerAccount.update(keyHash, SettingsBuilder.init().fromHook(mockHook));
        vm.stopPrank();

        bytes memory signature = p256Key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(keyHash, typedDataSignSignature, EMPTY_HOOK_DATA);

        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);

        mockHook.setIsValidSignatureReturnValue(true);
        bytes4 result = signerAccount.isValidSignature(digest, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_P256_wrappedSignature___typedDataSign_withHook");
        assertEq(result, _1271_MAGIC_VALUE);

        mockHook.setIsValidSignatureReturnValue(false);
        vm.prank(address(mockERC1271VerifyingContract));

        vm.expectRevert();
        signerAccount.isValidSignature(digest, wrappedSignature);
    }

    /**
     * Scenario: Root key
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_rootKey_wrappedSignature__nestedPersonalSign_isValid_gas() public {
        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));
        bytes32 signerAccountDomainSeparator = signerAccount.domainSeparator();
        bytes32 wrappedPersonalSignDigest =
            TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = signerTestKey.sign(wrappedPersonalSignDigest);
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(messageHash, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_rootKey_wrappedSignature__nestedPersonalSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: SECP256K1 key
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_secp256k1_wrappedSignature__nestedPersonalSign_isValid_gas() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, 0xb0b);
        vm.prank(address(signer));
        signerAccount.register(key.toKey());

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));
        bytes32 signerAccountDomainSeparator = signerAccount.domainSeparator();
        bytes32 wrappedPersonalSignDigest =
            TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = key.sign(wrappedPersonalSignDigest);
        bytes memory wrappedSignature = abi.encode(key.toKeyHash(), signature, EMPTY_HOOK_DATA);

        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(messageHash, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_secp256k1_wrappedSignature__nestedPersonalSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: P256 key
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_P256_wrappedSignature__nestedPersonalSign_isValid_gas() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));
        bytes32 signerAccountDomainSeparator = signerAccount.domainSeparator();
        bytes32 wrappedPersonalSignDigest =
            TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = p256Key.sign(wrappedPersonalSignDigest);
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(messageHash, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_P256_wrappedSignature__nestedPersonalSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     * Scenario: WebAuthn key
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     * = valid signature
     */
    /// forge-config: default.isolate = true
    /// forge-config: ci.isolate = true
    function test_isValidSignature_WebAuthnP256_wrappedSignature__nestedPersonalSign_isValid_gas() public {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);
        vm.prank(address(signer));
        signerAccount.register(webAuthnP256Key.toKey());

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));
        bytes32 signerAccountDomainSeparator = signerAccount.domainSeparator();
        bytes32 wrappedPersonalSignDigest =
            TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = webAuthnP256Key.sign(wrappedPersonalSignDigest);
        bytes memory wrappedSignature = abi.encode(webAuthnP256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);

        vm.prank(address(mockERC1271VerifyingContract));
        bytes4 result = signerAccount.isValidSignature(messageHash, wrappedSignature);
        vm.snapshotGasLastCall("isValidSignature_WebAuthnP256_wrappedSignature__nestedPersonalSign");
        assertEq(result, _1271_MAGIC_VALUE);
    }

    /**
     *
     * MARK: Expired key tests
     *
     */
    function test_isValidSignature_secp256k1_wrappedSignature___typedDataSign_expiredKey_reverts() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, 0xb0b);
        bytes memory signature = key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        vm.warp(100);
        Settings keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp - 1));

        vm.startPrank(address(signerAccount));
        signerAccount.register(key.toKey());
        signerAccount.update(key.toKeyHash(), keySettings);
        vm.stopPrank();

        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.expectRevert(abi.encodeWithSelector(IKeyManagement.KeyExpired.selector, uint40(block.timestamp - 1)));
        vm.prank(address(mockERC1271VerifyingContract));
        signerAccount.isValidSignature(digest, wrappedSignature);
    }

    function test_isValidSignature_P256_wrappedSignature___typedDataSign_expiredKey_reverts() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        bytes memory signature = p256Key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        vm.warp(100);
        Settings keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp - 1));

        vm.startPrank(address(signerAccount));
        signerAccount.register(p256Key.toKey());
        signerAccount.update(p256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.expectRevert(abi.encodeWithSelector(IKeyManagement.KeyExpired.selector, uint40(block.timestamp - 1)));
        vm.prank(address(mockERC1271VerifyingContract));
        signerAccount.isValidSignature(digest, wrappedSignature);
    }

    function test_isValidSignature_WebAuthnP256_wrappedSignature___typedDataSign_expiredKey_reverts() public {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);
        bytes memory signature = webAuthnP256Key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(webAuthnP256Key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        vm.warp(100);
        Settings keySettings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp - 1));

        vm.startPrank(address(signerAccount));
        signerAccount.register(webAuthnP256Key.toKey());
        signerAccount.update(webAuthnP256Key.toKeyHash(), keySettings);
        vm.stopPrank();

        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.expectRevert(abi.encodeWithSelector(IKeyManagement.KeyExpired.selector, uint40(block.timestamp - 1)));
        vm.prank(address(mockERC1271VerifyingContract));
        signerAccount.isValidSignature(digest, wrappedSignature);
    }

    /**
     *
     * MARK: Invalid signer tests
     *
     */

    /**
     * Scenario: SECP256K1 key
     * 1. Raw signature not from the root key
     * = invalid signer
     */
    function test_isValidSignature_secp256k1_rawSignature_invalidSigner() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, 0xb0b);
        vm.prank(address(signer));
        signerAccount.register(key.toKey());

        bytes32 digest = keccak256("test");
        bytes memory signature = key.sign(digest);

        assertEq(signerAccount.isValidSignature(digest, signature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: P256 key
     * 1. 64 or 65-byte signature not from the root key
     * = invalid signer
     */
    function test_isValidSignature_P256_rawSignature_invalidSigner() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signer));
        signerAccount.register(p256Key.toKey());

        bytes32 digest = keccak256("test");
        bytes memory signature = p256Key.sign(digest);

        assertEq(signerAccount.isValidSignature(digest, signature), _1271_INVALID_VALUE);
    }

    /// Webauthn signatures are longer than 65 bytes, so the first 32 bytes will be assumed to be the keyHash which will revert with KeyDoesNotExist()
    function test_isValidSignature_WebAuthnP256_rawSignature_reverts_withKeyDoesNotExist() public {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);
        vm.prank(address(signer));
        signerAccount.register(webAuthnP256Key.toKey());

        bytes32 digest = keccak256("test");
        bytes memory signature = webAuthnP256Key.sign(digest);

        vm.expectRevert(SliceOutOfBounds.selector);
        signerAccount.isValidSignature(digest, signature);
    }

    /// Do not include the key hash in the wrapped signature, causing the memory decoding of the WebAuthn struct to revert
    function test_isValidSignature_WebAuthnP256_wrappedSignature_missingKeyHash_reverts_inMemoryDecoding() public {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);

        bytes memory signature = webAuthnP256Key.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        // Intentionally don't wrap the signature with the key hash.
        bytes memory wrappedSignature = abi.encode(typedDataSignSignature, EMPTY_HOOK_DATA);

        vm.prank(address(signer));
        signerAccount.register(webAuthnP256Key.toKey());

        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        vm.expectRevert();
        signerAccount.isValidSignature(digest, wrappedSignature);
    }

    /**
     * Scenario: Root key sent a TypedDataSign signature but did not sign the correct digest
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_rootKey_wrappedSignature___typedDataSign_incorrectSignedDigest_invalidSigner()
        public
    {
        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        // This is unsafe to sign because `digest` is not nested within a TypedDataSign
        bytes memory signature = signerTestKey.sign(digest);
        // Still build the signature as expected to pass in memory abi decoding
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, typedDataSignSignature, EMPTY_HOOK_DATA);

        // ensure the call returns the ERC1271 invalid magic value
        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: SECP256K1 key sent a TypedDataSign signature but did not sign the correct digest
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_secp256k1_wrappedSignature___typedDataSign_incorrectSignedDigest_invalidSigner()
        public
    {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, 0xb0b);
        vm.prank(address(signer));
        signerAccount.register(key.toKey());

        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        // This is unsafe to sign because `digest` is not nested within a TypedDataSign
        bytes memory signature = key.sign(digest);
        // Still build the signature as expected to pass in memory abi decoding
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        // ensure the call returns the ERC1271 invalid magic value
        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: P256 key sent a TypedDataSign signature but did not sign the correct digest
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_P256_wrappedSignature___typedDataSign_incorrectSignedDigest_invalidSigner() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signer));
        signerAccount.register(p256Key.toKey());

        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        // This is unsafe to sign because `digest` is not nested within a TypedDataSign
        bytes memory signature = p256Key.sign(digest);
        // Still build the signature as expected to pass in memory abi decoding
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        // ensure the call returns the ERC1271 invalid magic value
        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: P256 key sent a TypedDataSign signature but the signed digest was not `sha256` hashed
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_P256_wrappedSignature___typedDataSign_notSha256Hashed_invalidSigner() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signer));
        signerAccount.register(p256Key.toKey());

        // We do not sign the sha256 hash of the digest, but the digest itself
        (bytes32 r, bytes32 s) = vm.signP256(p256Key.privateKey, TEST_TYPED_DATA_SIGN_DIGEST);
        bytes memory signature = abi.encodePacked(r, s);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);

        // ensure the call returns the ERC1271 invalid magic value
        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: WebAuthn key sent a TypedDataSign signature but did not sign the correct digest
     * We expect the revert to happen in KeyLib.verify() because we will try to decode the signature into a WebAuthn struct in memory
     */
    function test_isValidSignature_WebAuthnP256_wrappedSignature___typedDataSign_incorrectSignedDigest_reverts()
        public
    {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);
        vm.prank(address(signer));
        signerAccount.register(webAuthnP256Key.toKey());

        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        // This is unsafe to sign because `digest` is not nested within a TypedDataSign
        bytes memory signature = webAuthnP256Key.sign(digest);
        // Still build the signature as expected to pass in memory abi decoding
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(webAuthnP256Key.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        vm.expectRevert();
        signerAccount.isValidSignature(digest, wrappedSignature);
    }

    /**
     * Scenario: Root key did not sign for any valid flow
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_rootKey_wrappedSignature_invalidSigner() public view {
        bytes32 digest = keccak256("test");
        bytes memory signature = signerTestKey.sign(digest);
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: SECP256K1 key did not sign for any valid flow
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_secp256k1_wrappedSignature_invalidSigner() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, 0xb0b);
        vm.prank(address(signer));
        signerAccount.register(key.toKey());

        bytes32 digest = keccak256("test");
        // Sign a raw digest
        bytes memory signature = key.sign(digest);
        bytes memory wrappedSignature = abi.encode(key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        // Should return the invalid value
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: P256 key did not sign for any valid flow
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     *
     * = invalid signer
     */
    function test_isValidSignature_P256_wrappedSignature_invalidSigner() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signer));
        signerAccount.register(p256Key.toKey());

        bytes32 digest = keccak256("test");
        // Sign a raw digest
        bytes memory signature = p256Key.sign(digest);
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        // Should return the invalid value
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: WebAuthn key did not sign for any valid flow
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_WebAuthnP256_wrappedSignature_invalidSigner() public {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);
        vm.prank(address(signer));
        signerAccount.register(webAuthnP256Key.toKey());

        bytes32 digest = keccak256("test");
        bytes memory signature = webAuthnP256Key.sign(digest);
        bytes memory wrappedSignature = abi.encode(webAuthnP256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        // Should return the invalid value
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /// Sign with a private key and try to use a different key hash in the wrapped signature
    function test_isValidSignature_secp256k1_wrappedSignature___typedDataSign_wrongKeyHash_invalidSigner() public {
        // sign with a different private key
        uint256 invalidPrivateKey = 0xdeadbeef;
        TestKey memory invalidSigner = TestKeyManager.withSeed(KeyType.Secp256k1, invalidPrivateKey);
        bytes memory signature = invalidSigner.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        // trying to spoof the root key hash causes the signature verification to fail
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, typedDataSignSignature, EMPTY_HOOK_DATA);

        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        // ensure the call returns the ERC1271 invalid magic value
        assertEq(signerAccount.isValidSignature(digest, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: Root key sent a nested personal sign but did not sign the correct digest
     * @dev this would actually succeed if it was only a raw signature,
     *      but if a wrapped signature is passed in we enforce that it is valid for NestedPersonalSign
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_rootKey_wrappedSignature__nestedPersonalSign_invalidSigner() public view {
        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));

        // Sign the unsafe `messageHash` instead of `wrappedPersonalSignDigest` below
        // wrappedPersonalSignDigest =
        //     TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = signerTestKey.sign(messageHash);
        bytes memory wrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, signature, EMPTY_HOOK_DATA);
        assertEq(signerAccount.isValidSignature(messageHash, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: SECP256K1 key sent a nested personal sign but did not sign the correct digest
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_secp256k1_wrappedSignature__nestedPersonalSign_invalidSigner() public {
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, 0xb0b);
        vm.prank(address(signer));
        signerAccount.register(key.toKey());

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));

        // Sign the unsafe `messageHash` instead of `wrappedPersonalSignDigest` below
        // wrappedPersonalSignDigest =
        //     TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = key.sign(messageHash);
        bytes memory wrappedSignature = abi.encode(key.toKeyHash(), signature, EMPTY_HOOK_DATA);

        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(messageHash, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: P256 key sent a nested personal sign but did not sign the correct digest
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     *
     * = invalid signer
     */
    function test_isValidSignature_P256_wrappedSignature__nestedPersonalSign_invalidSigner() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);
        vm.prank(address(signer));
        signerAccount.register(p256Key.toKey());

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));

        // Sign the unsafe `messageHash` instead of `wrappedPersonalSignDigest` below
        // wrappedPersonalSignDigest =
        //     TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = p256Key.sign(messageHash);
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);

        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(messageHash, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: P256 key with valid nestedPersonalSign but the digest is not sha256 hashed
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Not nested personal sign
     * = invalid signature
     */
    function test_isValidSignature_P256_wrappedSignature__nestedPersonalSign_notSha256Hashed_invalidSignature() public {
        TestKey memory p256Key = TestKeyManager.initDefault(KeyType.P256);

        vm.prank(address(signerAccount));
        signerAccount.register(p256Key.toKey());

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));
        bytes32 signerAccountDomainSeparator = signerAccount.domainSeparator();
        bytes32 wrappedPersonalSignDigest =
            TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        // We do not sign the sha256 hash of the digest, but the digest itself
        (bytes32 r, bytes32 s) = vm.signP256(p256Key.privateKey, wrappedPersonalSignDigest);
        bytes memory signature = abi.encodePacked(r, s);
        bytes memory wrappedSignature = abi.encode(p256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);
        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(messageHash, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     * Scenario: WebAuthn key sent a nested personal sign but did not sign the correct digest
     * 1. Not raw signature
     * 2. Not typed data sign
     * 3. Nested personal sign
     * = invalid signer
     */
    function test_isValidSignature_WebAuthnP256_wrappedSignature__nestedPersonalSign_invalidSigner() public {
        TestKey memory webAuthnP256Key = TestKeyManager.initDefault(KeyType.WebAuthnP256);
        vm.prank(address(signer));
        signerAccount.register(webAuthnP256Key.toKey());

        string memory message = "test";
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(bytes(message));

        // Sign the unsafe `messageHash` instead of `wrappedPersonalSignDigest` below
        // wrappedPersonalSignDigest =
        //     TypedDataSignBuilder.hashWrappedPersonalSign(messageHash, signerAccountDomainSeparator);

        bytes memory signature = webAuthnP256Key.sign(messageHash);
        bytes memory wrappedSignature = abi.encode(webAuthnP256Key.toKeyHash(), signature, EMPTY_HOOK_DATA);

        vm.prank(address(mockERC1271VerifyingContract));
        assertEq(signerAccount.isValidSignature(messageHash, wrappedSignature), _1271_INVALID_VALUE);
    }

    /**
     *
     * MARK: Other revert tests
     *
     */
    function test_isValidSignature_newDomainSeparatorInvalidatesOldSignatures() public {
        bytes memory signature = signerTestKey.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory oldWrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, typedDataSignSignature, EMPTY_HOOK_DATA);
        // ensure the call returns the ERC1271 magic value
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        // Make sure it is a valid signature before the domain separator is updated
        bytes4 result = signerAccount.isValidSignature(digest, oldWrappedSignature);
        assertEq(result, _1271_MAGIC_VALUE);

        // Update the salt prefix, which changes the domain separator
        vm.prank(address(signerAccount));
        signerAccount.updateSalt(uint96(0x1));

        // Expect the old signature to be invalidated
        result = signerAccount.isValidSignature(digest, oldWrappedSignature);
        assertEq(result, _1271_INVALID_VALUE);

        // Build the new typed data sign digest
        // Everything stays the same besides the signer account's domainBytes
        bytes memory signerAccountDomainBytes = IERC5267(address(signerAccount)).toDomainBytes();
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        bytes32 newTypedDataSignDigest =
            contentsHash.hashTypedDataSign(signerAccountDomainBytes, appDomainSeparator, contentsName, contentsType);

        // Build the new wrapped signature
        bytes memory newSignature = signerTestKey.sign(newTypedDataSignDigest);
        bytes memory newTypedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            newSignature, appDomainSeparator, contentsHash, contentsDescr
        );

        // Ensure we can sign with the new domain separator
        bytes memory newWrappedSignature = abi.encode(KeyLib.ROOT_KEY_HASH, newTypedDataSignSignature, EMPTY_HOOK_DATA);
        result = signerAccount.isValidSignature(digest, newWrappedSignature);
        assertEq(result, _1271_MAGIC_VALUE);
    }

    function test_isValidSignature_secp256k1_wrappedSignature_reverts_keyDoesNotExist() public {
        // sign with an unregistered private key
        uint256 invalidPrivateKey = 0xdeadbeef;
        TestKey memory invalidSigner = TestKeyManager.withSeed(KeyType.Secp256k1, invalidPrivateKey);
        bytes memory signature = invalidSigner.sign(TEST_TYPED_DATA_SIGN_DIGEST);
        (bytes32 appDomainSeparator, string memory contentsDescr, bytes32 contentsHash) = getERC1271Fixtures();
        bytes memory typedDataSignSignature = TypedDataSignBuilder.buildTypedDataSignSignature(
            signature, appDomainSeparator, contentsHash, contentsDescr
        );
        bytes memory wrappedSignature = abi.encode(invalidSigner.toKeyHash(), typedDataSignSignature, EMPTY_HOOK_DATA);

        // Built by the ERC1271 contract which hashes its domain separator to the contents hash
        bytes32 digest = mockERC1271VerifyingContract.hashTypedDataV4(contentsHash);
        vm.prank(address(mockERC1271VerifyingContract));
        vm.expectRevert(IKeyManagement.KeyDoesNotExist.selector);
        signerAccount.isValidSignature(digest, wrappedSignature);
    }
}
