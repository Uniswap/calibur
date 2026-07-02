// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC5267} from "openzeppelin-contracts/contracts/interfaces/IERC5267.sol";
import {DelegationHandler} from "./utils/DelegationHandler.sol";
import {IERC1271} from "../src/interfaces/IERC1271.sol";
import {IEIP712} from "../src/interfaces/IEIP712.sol";
import {HandlerCall, CallUtils} from "./utils/CallUtils.sol";
import {Call} from "../src/libraries/CallLib.sol";
import {CallLib} from "../src/libraries/CallLib.sol";
import {KeyType} from "../src/libraries/KeyLib.sol";
import {PrefixedSaltLib} from "../src/libraries/PrefixedSaltLib.sol";
import {TestKeyManager, TestKey} from "./utils/TestKeyManager.sol";
import {TokenHandler} from "./utils/TokenHandler.sol";
import {FFISignTypedData} from "./utils/FFISignTypedData.sol";
import {SignedBatchedCallLib, SignedBatchedCall} from "../src/libraries/SignedBatchedCallLib.sol";
import {BatchedCallLib, BatchedCall} from "../src/libraries/BatchedCallLib.sol";

contract ERC712Test is DelegationHandler, TokenHandler, FFISignTypedData {
    using CallLib for Call[];
    using CallUtils for *;
    using TestKeyManager for TestKey;
    using SignedBatchedCallLib for SignedBatchedCall;
    using BatchedCallLib for BatchedCall;

    address receiver = makeAddr("receiver");

    function setUp() public {
        setUpDelegation();
        setUpTokens();
    }

    function test_eip712Domain() public view {
        (
            ,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = signerAccount.eip712Domain();
        assertEq(name, "Calibur");
        assertEq(version, "1.0.0");
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(signerAccount));
        assertEq(abi.encode(extensions), abi.encode(new uint256[](0)));
        assertEq(salt, PrefixedSaltLib.pack(uint96(0), address(calibur)));
    }

    function test_domainBytes() public view {
        bytes memory domainBytes = signerAccount.domainBytes();
        (bytes32 hashedName, bytes32 hashedVersion, uint256 chainId, address verifyingContract, bytes32 salt) =
            abi.decode(domainBytes, (bytes32, bytes32, uint256, address, bytes32));
        assertEq(hashedName, keccak256(bytes("Calibur")));
        assertEq(hashedVersion, keccak256(bytes("1.0.0")));
        assertEq(chainId, block.chainid);
        assertEq(verifyingContract, address(signerAccount));
        assertEq(salt, PrefixedSaltLib.pack(uint96(0), address(calibur)));
    }

    function test_domainSeparator() public view {
        (
            ,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = signerAccount.eip712Domain();
        // Ensure that verifying contract is the signer
        assertEq(verifyingContract, address(signerAccount));
        assertEq(abi.encode(extensions), abi.encode(new uint256[](0)));
        assertEq(salt, PrefixedSaltLib.pack(uint96(0), address(calibur)));
        assertEq(name, "Calibur");
        assertEq(version, "1.0.0");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract,
                salt
            )
        );
        assertEq(expected, signerAccount.domainSeparator());
    }

    function test_hashTypedData() public view {
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall();
        bytes32 hashTypedData = signerAccount.hashTypedData(signedBatchedCall.hash());
        // re-implement 712 hash
        bytes32 expected =
            keccak256(abi.encodePacked("\x19\x01", signerAccount.domainSeparator(), signedBatchedCall.hash()));
        assertEq(expected, hashTypedData);
    }

    function test_hashTypedData_matches_signedTypedData_ffi() public {
        Call[] memory calls = CallUtils.initArray();
        calls = calls.push(buildTransferCall(address(tokenA), address(receiver), 1e18));
        uint256 nonce = 0;
        BatchedCall memory batchedCall = CallUtils.initBatchedCall().withCalls(calls).withRevertOnFailure(true);
        SignedBatchedCall memory signedBatchedCall = CallUtils.initSignedBatchedCall().withBatchedCall(batchedCall)
            .withNonce(nonce).withExecutor(address(1)).withDeadline(block.timestamp + 300000);
        TestKey memory key = TestKeyManager.withSeed(KeyType.Secp256k1, signerPrivateKey);
        // Make it clear that the verifying contract is set properly.
        address verifyingContract = address(signerAccount);
        (,,,,, bytes32 salt,) = signerAccount.eip712Domain();

        (bytes memory signature) = ffi_signTypedData(signerPrivateKey, signedBatchedCall, verifyingContract, salt);

        assertEq(signature, key.sign(signerAccount.hashTypedData(signedBatchedCall.hash())));
    }

    function test_updateSalt() public {
        // _saltPrefix starts at 0, so a single increment yields 1
        uint96 _prefix = uint96(0x1);

        vm.prank(address(signerAccount));
        signerAccount.updateSalt();

        (, string memory name, string memory version, uint256 chainId, address verifyingContract, bytes32 salt,) =
            signerAccount.eip712Domain();

        bytes32 expectedSalt = PrefixedSaltLib.pack(_prefix, address(calibur));
        assertEq(salt, expectedSalt);

        bytes32 expected = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract,
                expectedSalt
            )
        );
        assertEq(expected, signerAccount.domainSeparator());
    }
}
