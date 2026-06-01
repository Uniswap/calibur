// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Call} from "../../src/libraries/CallLib.sol";
import {IKeyManagement} from "../../src/interfaces/IKeyManagement.sol";
import {IERC7821} from "../../src/interfaces/IERC7821.sol";
import {Settings} from "../../src/libraries/SettingsLib.sol";
import {TestKeyManager, TestKey} from "./TestKeyManager.sol";
import {BatchedCall} from "../../src/libraries/BatchedCallLib.sol";
import {SignedBatchedCall} from "../../src/libraries/SignedBatchedCallLib.sol";
import {Vm} from "forge-std/Vm.sol";

/// @dev A wrapper around Call that includes callback data for processing after execution
struct HandlerCall {
    Call call;
    bytes callback;
    bytes revertData;
}

/// @dev Utility library for Call and HandlerCall objects
library CallUtils {
    using CallUtils for Call;
    using CallUtils for Call[];
    using CallUtils for BatchedCall;
    using CallUtils for HandlerCall;
    using CallUtils for HandlerCall[];
    using TestKeyManager for TestKey;

    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Constants
    address constant SELF_CALL = address(0);
    bytes32 internal constant BATCHED_CALL = 0x0100000000000000000000000000000000000000000000000000000000000000;

    // Call array operations

    /// @dev Create empty Call array
    function initArray() internal pure returns (Call[] memory) {
        return new Call[](0);
    }

    /// @dev Add a call to an array
    function push(Call[] memory calls, Call memory call) internal pure returns (Call[] memory) {
        Call[] memory newCalls = new Call[](calls.length + 1);
        for (uint256 i = 0; i < calls.length; i++) {
            newCalls[i] = calls[i];
        }
        newCalls[calls.length] = call;
        return newCalls;
    }

    function containsSelfCall(Call[] memory calls) internal pure returns (bool) {
        for (uint256 i = 0; i < calls.length; i++) {
            if (calls[i].to == SELF_CALL) {
                return true;
            }
        }
        return false;
    }

    // Call manipulation

    /// @dev Create default empty Call
    function initDefault() internal pure returns (Call memory) {
        return Call({to: address(0), value: 0, data: ""});
    }

    function withTo(Call memory call, address to) internal pure returns (Call memory) {
        call.to = to;
        return call;
    }

    function withValue(Call memory call, uint256 value) internal pure returns (Call memory) {
        call.value = value;
        return call;
    }

    function withData(Call memory call, bytes memory data) internal pure returns (Call memory) {
        call.data = data;
        return call;
    }

    /// @dev Create call to register key
    function encodeRegisterCall(TestKey memory newKey) internal pure returns (Call memory) {
        return initDefault().withTo(SELF_CALL)
            .withData(abi.encodeWithSelector(IKeyManagement.register.selector, newKey.toKey()));
    }

    /// @dev Create call to revoke key
    function encodeRevokeCall(bytes32 keyHash) internal pure returns (Call memory) {
        return initDefault().withTo(SELF_CALL).withData(abi.encodeWithSelector(IKeyManagement.revoke.selector, keyHash));
    }

    /// @dev Create call to update key settings
    function encodeUpdateCall(bytes32 keyHash, Settings settings) internal pure returns (Call memory) {
        return initDefault().withTo(SELF_CALL)
            .withData(abi.encodeWithSelector(IKeyManagement.update.selector, keyHash, settings));
    }

    // BatchedCall operations

    function initBatchedCall() internal pure returns (BatchedCall memory) {
        return BatchedCall({calls: new Call[](0), revertOnFailure: false});
    }

    function withCalls(BatchedCall memory batchedCall, Call[] memory calls) internal pure returns (BatchedCall memory) {
        batchedCall.calls = calls;
        return batchedCall;
    }

    function withRevertOnFailure(BatchedCall memory batchedCall, bool revertOnFailure)
        internal
        pure
        returns (BatchedCall memory)
    {
        batchedCall.revertOnFailure = revertOnFailure;
        return batchedCall;
    }

    // SignedBatchedCall operations
    function initSignedBatchedCall() internal pure returns (SignedBatchedCall memory) {
        return SignedBatchedCall({
            batchedCall: initBatchedCall(), keyHash: bytes32(0), nonce: 0, executor: address(0), deadline: 0
        });
    }

    function withDeadline(SignedBatchedCall memory signedBatchedCall, uint256 deadline)
        internal
        pure
        returns (SignedBatchedCall memory)
    {
        signedBatchedCall.deadline = deadline;
        return signedBatchedCall;
    }

    function withBatchedCall(SignedBatchedCall memory signedBatchedCall, BatchedCall memory batchedCall)
        internal
        pure
        returns (SignedBatchedCall memory)
    {
        signedBatchedCall.batchedCall = batchedCall;
        return signedBatchedCall;
    }

    function withKeyHash(SignedBatchedCall memory signedBatchedCall, bytes32 keyHash)
        internal
        pure
        returns (SignedBatchedCall memory)
    {
        signedBatchedCall.keyHash = keyHash;
        return signedBatchedCall;
    }

    function withNonce(SignedBatchedCall memory signedBatchedCall, uint256 nonce)
        internal
        pure
        returns (SignedBatchedCall memory)
    {
        signedBatchedCall.nonce = nonce;
        return signedBatchedCall;
    }

    function withExecutor(SignedBatchedCall memory signedBatchedCall, address executor)
        internal
        pure
        returns (SignedBatchedCall memory)
    {
        signedBatchedCall.executor = executor;
        return signedBatchedCall;
    }
    /// @dev Create a single execute call for a multicall with a signed batched call

    function encodeSignedExecuteCall(SignedBatchedCall memory signedBatchedCall, bytes memory signature)
        internal
        pure
        returns (bytes memory)
    {
        bytes4 executeSelector =
            bytes4(keccak256("execute((((address,uint256,bytes)[],bool),uint256,bytes32,address,uint256),bytes)"));
        return abi.encodeWithSelector(executeSelector, signedBatchedCall, signature);
    }

    /// @dev Create a single execute call for a multicall with a batched call
    function encodeBatchedExecuteCall(BatchedCall memory batchedCall) internal pure returns (bytes memory) {
        bytes4 executeSelector = bytes4(keccak256("execute(((address,uint256,bytes)[],bool))"));
        return abi.encodeWithSelector(executeSelector, batchedCall);
    }

    // HandlerCall operations

    /// @dev Create empty HandlerCall array
    function initHandlerArray() internal pure returns (HandlerCall[] memory) {
        return new HandlerCall[](0);
    }

    /// @dev Add a HandlerCall to array
    function push(HandlerCall[] memory handlerCalls, HandlerCall memory handlerCall)
        internal
        pure
        returns (HandlerCall[] memory)
    {
        HandlerCall[] memory newCalls = new HandlerCall[](handlerCalls.length + 1);
        for (uint256 i = 0; i < handlerCalls.length; i++) {
            newCalls[i] = handlerCalls[i];
        }
        newCalls[handlerCalls.length] = handlerCall;
        return newCalls;
    }

    /// @dev Convert HandlerCall array to Call array
    function toCalls(HandlerCall[] memory handlerCalls) internal pure returns (Call[] memory) {
        Call[] memory calls = new Call[](handlerCalls.length);
        for (uint256 i = 0; i < handlerCalls.length; i++) {
            calls[i] = handlerCalls[i].call;
        }
        return calls;
    }

    /// @dev Create default empty HandlerCall
    function initHandlerDefault() internal pure returns (HandlerCall memory) {
        return HandlerCall({call: initDefault(), callback: "", revertData: ""});
    }

    function withCall(HandlerCall memory handlerCall, Call memory call) internal pure returns (HandlerCall memory) {
        handlerCall.call = call;
        return handlerCall;
    }

    function withCallback(HandlerCall memory handlerCall, bytes memory callback)
        internal
        pure
        returns (HandlerCall memory)
    {
        handlerCall.callback = callback;
        return handlerCall;
    }

    function withRevertData(HandlerCall memory handlerCall, bytes memory revertData)
        internal
        pure
        returns (HandlerCall memory)
    {
        handlerCall.revertData = revertData;
        return handlerCall;
    }
}
