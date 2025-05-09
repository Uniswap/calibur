// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {CalldataDecoder} from "../../src/libraries/CalldataDecoder.sol";
import {MockCalldataDecoder} from "../utils/MockCalldataDecoder.sol";

contract CalldataDecoderTest is Test {
    using CalldataDecoder for bytes;

    MockCalldataDecoder decoder;

    function setUp() public {
        decoder = new MockCalldataDecoder();
    }

    function test_removeSelector() public view {
        bytes4 selector = bytes4(keccak256("test"));
        bytes memory data = abi.encodeWithSelector(selector, uint256(1), uint256(2));
        bytes memory dataWithoutSelector = decoder.removeSelector(data);

        (uint256 one, uint256 two) = abi.decode(dataWithoutSelector, (uint256, uint256));
        assertEq(one, 1);
        assertEq(two, 2);
    }

    function test_decodeSignatureWithHookData_fuzz(bytes memory arg1, bytes memory arg2) public view {
        bytes memory data = abi.encode(arg1, arg2);
        (bytes memory _arg1, bytes memory _arg2) = decoder.decodeSignatureWithHookData(data);
        assertEq(_arg1, arg1);
        assertEq(_arg2, arg2);
    }

    function test_decodeSignatureWithKeyHashAndHookData_fuzz(bytes32 arg1, bytes memory arg2, bytes memory arg3)
        public
        view
    {
        bytes memory data = abi.encode(arg1, arg2, arg3);
        (bytes32 _arg1, bytes memory _arg2, bytes memory _arg3) = decoder.decodeSignatureWithKeyHashAndHookData(data);
        assertEq(_arg1, arg1);
        assertEq(_arg2, arg2);
        assertEq(_arg3, arg3);
    }

    function test_decodeTypedDataSig_fuzz(bytes memory arg1, bytes32 arg2, bytes32 arg3, string memory arg4)
        public
        view
    {
        bytes memory data = abi.encode(arg1, arg2, arg3, arg4);
        (bytes memory _arg1, bytes32 _arg2, bytes32 _arg3, string memory _arg4) = decoder.decodeTypedDataSig(data);
        assertEq(_arg1, arg1);
        assertEq(_arg2, arg2);
        assertEq(_arg3, arg3);
        assertEq(_arg4, arg4);
    }

    /// Offchain implementations may also encode the length of the contentsDescr in the calldata
    /// We do not use it in our implementation, but we should test that it does not affect the decoding of the other values
    function test_decodeTypedDataSig_withContentsDescrLength_fuzz(bytes memory arg1, bytes32 arg2, bytes32 arg3, string memory arg4, uint16 arg5)
        public
        view
    {
        bytes memory data = abi.encode(arg1, arg2, arg3, arg4, arg5);
        (bytes memory _arg1, bytes32 _arg2, bytes32 _arg3, string memory _arg4) = decoder.decodeTypedDataSig(data);
        assertEq(_arg1, arg1);
        assertEq(_arg2, arg2);
        assertEq(_arg3, arg3);
        assertEq(_arg4, arg4);
    }
}