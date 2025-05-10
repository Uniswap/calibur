// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {CalldataDecoder} from "../../src/libraries/CalldataDecoder.sol";
import {MockCalldataDecoder} from "../utils/MockCalldataDecoder.sol";

contract CalldataDecoderTest is Test {
    using CalldataDecoder for bytes;

    error SliceOutOfBounds();

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

    function test_removeSelector_lessThan4Bytes_reverts() public {
        bytes memory selector = hex"4e4e4e";
        vm.expectRevert(abi.encodeWithSelector(SliceOutOfBounds.selector));
        decoder.removeSelector(selector);
    }

    function test_removeSelector_exactly4Bytes_doesNotRevert() public view {
        bytes memory selector = hex"4e4e4e4e";
        bytes memory dataWithoutSelector = decoder.removeSelector(selector);

        assertEq(dataWithoutSelector, "");
    }
}
