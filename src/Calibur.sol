// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {Receiver} from "solady/accounts/Receiver.sol";
import {P256} from "@openzeppelin/contracts/utils/cryptography/P256.sol";
import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {ISenderCreator} from "account-abstraction/interfaces/ISenderCreator.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {IERC1271} from "./interfaces/IERC1271.sol";
import {IERC7821} from "./interfaces/IERC7821.sol";
import {IHook} from "./interfaces/IHook.sol";
import {IKeyManagement} from "./interfaces/IKeyManagement.sol";
import {ICalibur} from "./interfaces/ICalibur.sol";
import {EIP712} from "./EIP712.sol";
import {ERC1271} from "./ERC1271.sol";
import {ERC4337Account} from "./ERC4337Account.sol";
import {ERC7201} from "./ERC7201.sol";
import {ERC7821} from "./ERC7821.sol";
import {ERC7914} from "./ERC7914.sol";
import {ERC7739} from "./ERC7739.sol";
import {KeyManagement} from "./KeyManagement.sol";
import {NonceManager} from "./NonceManager.sol";
import {BatchedCallLib, BatchedCall} from "./libraries/BatchedCallLib.sol";
import {Call, CallLib} from "./libraries/CallLib.sol";
import {CalldataDecoder} from "./libraries/CalldataDecoder.sol";
import {HooksLib} from "./libraries/HooksLib.sol";
import {Key, KeyLib} from "./libraries/KeyLib.sol";
import {ModeDecoder} from "./libraries/ModeDecoder.sol";
import {Settings, SettingsLib} from "./libraries/SettingsLib.sol";
import {SignedBatchedCallLib, SignedBatchedCall} from "./libraries/SignedBatchedCallLib.sol";
import {WrappedSignatureLib} from "./libraries/WrappedSignatureLib.sol";

/// @title Calibur
/// @notice A singleton contract wallet supporting batched transactions, alternative signers, and native ETH transferFrom
/// @dev Delegate to Calibur from an EOA using EIP-7702
/// @custom:security-contact security@uniswap.org
contract Calibur is
    ICalibur,
    ERC7821,
    ERC1271,
    ERC4337Account,
    KeyManagement,
    NonceManager,
    ERC7914,
    ERC7201,
    ERC7739,
    EIP712,
    Receiver
{
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using CallLib for Call[];
    using BatchedCallLib for BatchedCall;
    using SignedBatchedCallLib for SignedBatchedCall;
    using KeyLib for *;
    using ModeDecoder for bytes32;
    using CalldataDecoder for bytes;
    using HooksLib for IHook;
    using SettingsLib for Settings;
    using WrappedSignatureLib for bytes;

    /// @inheritdoc ICalibur
    function execute(BatchedCall memory batchedCall) public payable {
        bytes32 keyHash = msg.sender.toKeyHash();
        if (!_isOwnerOrValidKey(keyHash)) revert Unauthorized();
        _processBatch(batchedCall, keyHash);
    }

    /// @inheritdoc ICalibur
    function execute(SignedBatchedCall calldata signedBatchedCall, bytes calldata wrappedSignature) public payable {
        if (!_senderIsExecutor(signedBatchedCall.executor)) revert Unauthorized();
        _handleVerifySignature(signedBatchedCall, wrappedSignature);
        _processBatch(signedBatchedCall.batchedCall, signedBatchedCall.keyHash);
    }

    /// @inheritdoc IERC7821
    function execute(bytes32 mode, bytes calldata executionData) external payable override {
        if (!mode.isBatchedCall()) revert IERC7821.UnsupportedExecutionMode();
        Call[] memory calls = abi.decode(executionData, (Call[]));
        BatchedCall memory batchedCall = BatchedCall({calls: calls, revertOnFailure: mode.revertOnFailure()});
        execute(batchedCall);
    }

    /// @notice This function is executeable only by the EntryPoint contract, and is the main pathway for UserOperations to be executed.
    /// @dev UserOperations can be executed through the execute function, but another method of authorization (ie through a passed in signature) is required.
    ///      `userOp.callData` is `abi.encodeCall(IAccountExecute.executeUserOp.selector, (abi.encode(Call[]), bool))`
    ///      Note that this contract is only compatible with Entrypoint versions v0.7.0 and v0.8.0.
    ///      It is not compatible with v0.6.0, as that version does not support the "executeUserOp" selector.
    function executeUserOp(PackedUserOperation calldata userOp, bytes32) external onlyEntryPoint {
        // If no keyHash is provided, we know that `validateUserOp` has validated the raw signature against the root key.
        // This default behavior is safe as long as the Entrypoint ensures `validateUserOp` is called before this function
        bytes32 keyHash;
        if (!userOp.signature.isRawSignature()) {
            // Otherwise, parse the keyHash from the signature and pass it along to verify other permissions over the call execution.
            (keyHash,,) = userOp.signature.decodeWithKeyHashAndHookData();
        }

        bytes calldata executionData = userOp.callData.removeSelector();
        (BatchedCall memory batchedCall) = abi.decode(executionData, (BatchedCall));

        _processBatch(batchedCall, keyHash);
    }

    /// @inheritdoc IAccount
    /// @dev Only return validationData if the signature from the key associated with `keyHash` is valid over the userOpHash
    ///      - The ERC-4337 spec requires that `validateUserOp` does not early return if the signature is invalid such that accurate gas estimation can be done
    /// @return validationData is (uint256(validAfter) << (160 + 48)) | (uint256(validUntil) << 160) | (isValid ? 0 : 1)
    /// - `validAfter` is always 0.
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        _payEntryPoint(missingAccountFunds);

        if (userOp.signature.isRawSignature()) {
            validationData = KeyLib.toRootKey().verify(userOpHash, userOp.signature)
                ? SIG_VALIDATION_SUCCEEDED
                : SIG_VALIDATION_FAILED;
        } else {
            (bytes32 keyHash, bytes calldata signature, bytes calldata hookData) =
                userOp.signature.decodeWithKeyHashAndHookData();

            /// Per ERC-4337, return invalid signature rather than reverting if the key is not registered
            if (!keyHash.isRootKey() && !isRegistered(keyHash)) return SIG_VALIDATION_FAILED;

            Key memory key = getKey(keyHash);
            /// The userOpHash does not need to be made replay-safe, as the EntryPoint will always call the sender contract of the UserOperation for validation.
            bool isValid = key.verify(userOpHash, signature);

            Settings settings = getKeySettings(keyHash);

            /// validationData is (uint256(validAfter) << (160 + 48)) | (uint256(validUntil) << 160) | (success ? 0 : 1)
            /// `validAfter` is always 0.
            validationData =
                isValid ? uint256(settings.expiration()) << 160 | SIG_VALIDATION_SUCCEEDED : SIG_VALIDATION_FAILED;

            settings.hook().handleAfterValidateUserOp(keyHash, userOp, userOpHash, validationData, hookData);
        }
    }

    /// @inheritdoc ERC1271
    function isValidSignature(bytes32 digest, bytes calldata wrappedSignature)
        public
        view
        override(ERC1271, IERC1271)
        returns (bytes4)
    {
        // Per ERC-7739, return 0x77390001 for the sentinel hash value
        unchecked {
            if (wrappedSignature.isEmpty()) {
                // Forces the compiler to optimize for smaller bytecode size.
                if (uint256(digest) == ~wrappedSignature.length / 0xffff * 0x7739) return 0x77390001;
            }
            // If the signature is 64 or 65 bytes, it must be validated against the root key.
            // We skip any checks against expiry or hooks because settings are not supported on the root key.
            // Accept either a raw ECDSA signature over `digest` or an ERC-7739 PersonalSign over the account-nested digest.
            else if (wrappedSignature.isRawSignature()) {
                Key memory rootKey = KeyLib.toRootKey();
                if (
                    rootKey.verify(digest, wrappedSignature)
                        || _isValidNestedPersonalSig(rootKey, digest, domainSeparator(), wrappedSignature)
                ) {
                    return _1271_MAGIC_VALUE;
                } else {
                    return _1271_INVALID_VALUE;
                }
            }
        }

        (bytes32 keyHash, bytes calldata signature, bytes calldata hookData) =
            wrappedSignature.decodeWithKeyHashAndHookData();

        Key memory key = getKey(keyHash);
        /// Signature deduction flow as specified by ERC-7739
        // If the signature contains enough data for a TypedDataSign, try the TypedDataSign flow
        bool isValid = _isValidTypedDataSig(key, digest, domainBytes(), signature)
            // If the signature is not valid as a TypedDataSign, try the NestedPersonalSign flow
            || _isValidNestedPersonalSig(key, digest, domainSeparator(), signature);

        // Early return if the signature is invalid
        if (!isValid) return _1271_INVALID_VALUE;

        Settings settings = getKeySettings(keyHash);
        _checkExpiry(settings);

        settings.hook().handleAfterIsValidSignature(keyHash, digest, hookData);

        return _1271_MAGIC_VALUE;
    }

    /// @notice Prevent registering protected addresses as keys on the account
    function _checkCanRegister(Key memory key) internal view override {
        bytes32 keyHash = key.hash();
        address entryPoint = ENTRY_POINT();
        if (keyHash == entryPoint.toKeyHash()) revert IKeyManagement.CannotRegisterKey(key);

        // success is not required to be true to prevent bricking of all key registrations if the entryPoint is not set up correctly
        (bool success, bytes memory output) =
            entryPoint.staticcall(abi.encodeWithSelector(IEntryPoint.senderCreator.selector));
        if (success && output.length >= 32) {
            address senderCreator = abi.decode(output, (address));
            if (keyHash == senderCreator.toKeyHash()) revert IKeyManagement.CannotRegisterKey(key);
        }
    }

    /// @dev Iterates through calls, reverting according to specified failure mode
    function _processBatch(BatchedCall memory batchedCall, bytes32 keyHash) private {
        for (uint256 i = 0; i < batchedCall.calls.length; i++) {
            (bool success, bytes memory output) = _process(batchedCall.calls[i], keyHash);
            // Reverts with the first call that is unsuccessful if `revertOnFailure` is set to true
            // This does not catch hook reverts which cause the entire call to revert regardless of the value of `revertOnFailure`
            if (!success && batchedCall.revertOnFailure) revert ICalibur.CallFailed(output);
        }
    }

    /// @dev Executes a low level call using execution hooks if set
    function _process(Call memory _call, bytes32 keyHash) private returns (bool success, bytes memory output) {
        // Per ERC7821, replace address(0) with address(this)
        address to = _call.to == address(0) ? address(this) : _call.to;

        Settings settings = getKeySettings(keyHash);

        // By default, only the root key or admin keys can self-call. This is to prevent untrusted keys from updating their own settings
        // However, admin keys CAN update their own settings and evade the hook checks below
        // To prevent this, we recommend adding a hook which disallows calls by admin keys to the `register` and `update` functions
        if (!settings.isAdmin() && to == address(this)) revert IKeyManagement.OnlyAdminCanSelfCall();

        // Calls to the EntryPoint move account-owned deposit/stake (e.g. withdrawTo drains the account's deposit
        // as a zero-value call), so they are gated to admin keys like self-calls.
        if (!settings.isAdmin() && to == ENTRY_POINT()) revert IKeyManagement.OnlyAdminCanCallEntryPoint();

        IHook hook = settings.hook();
        bytes memory beforeExecuteData = hook.handleBeforeExecute(keyHash, to, _call.value, _call.data);

        (success, output) = to.call{value: _call.value}(_call.data);

        hook.handleAfterExecute(keyHash, success, output, beforeExecuteData);
    }

    /// @dev This function is used to handle the verification of signatures sent through execute()
    function _handleVerifySignature(SignedBatchedCall calldata signedBatchedCall, bytes calldata wrappedSignature)
        private
    {
        uint256 deadline = signedBatchedCall.deadline;
        if (deadline != 0 && block.timestamp > deadline) revert SignatureExpired();

        _useNonce(signedBatchedCall.nonce);

        (bytes calldata signature, bytes calldata hookData) = wrappedSignature.decodeWithHookData();

        bytes32 digest = hashTypedData(signedBatchedCall.hash());

        Key memory key = getKey(signedBatchedCall.keyHash);
        bool isValid = key.verify(digest, signature);
        if (!isValid) revert ICalibur.InvalidSignature();

        Settings settings = getKeySettings(signedBatchedCall.keyHash);
        _checkExpiry(settings);

        settings.hook().handleAfterVerifySignature(signedBatchedCall.keyHash, digest, hookData);
    }

    /// @notice Returns true if the msg.sender is the executor or if the executor is address(0)
    /// @param executor The address of the allowed executor of the signed batched call
    function _senderIsExecutor(address executor) private view returns (bool) {
        return executor == address(0) || executor == msg.sender;
    }
}
