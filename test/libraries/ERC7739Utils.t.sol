// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {MockERC7739Utils} from "../utils/MockERC7739Utils.sol";

/// @title ERC7739UtilsTest
/// @notice Test suite for the ERC7739Utils library
/// @author fixtures from https://github.com/OpenZeppelin/openzeppelin-community-contracts/blob/53f590e4f4902bee0e06e455332e3321c697ea8b/test/utils/cryptography/ERC7739Utils.test.js
contract ERC7739UtilsTest is Test {
    MockERC7739Utils mockERC7739Utils;

    function setUp() public {
        mockERC7739Utils = new MockERC7739Utils();
    }

    function test_decodeContentsDescr_returnsEmptyStringsIfEmptyDescriptor() public view {
        string memory contentsDescr = "";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");
    }

    function test_decodeContentsDescr_implicitMode_returnsContentsNameAndType() public view {
        string memory contentsDescr = "SomeType(address foo,uint256 bar)";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "SomeType");
        assertEq(contentsType, "SomeType(address foo,uint256 bar)");
    }

    function test_decodeContentsDescr_implicitMode_returnsEmptyStringsIfNoName() public view {
        string memory contentsDescr = "(SomeType(address foo,uint256 bar)"; // starts with (
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");
    }

    function test_decodeContentsDescr_implicityMode_returnsEmptyStringsIfNoParentheses() public view {
        string memory contentsDescr = "SomeType";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");
    }

    function test_decodeContentsDescr_explicitMode_returnsContentsNameAndType() public view {
        string memory contentsDescr = "A(C c)B(A a)C(uint256 v)B";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "B");
        assertEq(contentsType, "A(C c)B(A a)C(uint256 v)");
    }

    function test_decodeContentsDescr_explicitMode_returnsEmptyStringsIfStartsWithParentheses() public view {
        string memory contentsDescr = "(SomeType(address foo,uint256 bar)(SomeType";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");
    }

    function test_decodeContentsDescr_implicitMode_returnsEmptyStrings_ifInvalidChar() public view {
        // invalid char: ,
        string memory contentsDescr = "SomeType,(address foo,uint256 bar)";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");

        // invalid char: space
        contentsDescr = "SomeType (address foo,uint256 bar)";
        (contentsName, contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");

        // invalid char: )
        contentsDescr = "SomeType)(address foo,uint256 bar)";
        (contentsName, contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");

        // invalid char: \x00
        contentsDescr = "SomeType\x00(address foo,uint256 bar)";
        (contentsName, contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");
    }

    /// Explicit mode searches from the end of the string
    function test_decodeContentsDescr_explicitMode_returnsEmptyStrings_ifInvalidChar() public view {
        // invalid char: ,
        string memory contentsDescr = "A(C c)B(A a)C(uint256 v),B";
        (string memory contentsName, string memory contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");

        // invalid char: space
        contentsDescr = "A(C c)B(A a)C(uint256 v) B";
        (contentsName, contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");

        // We can't catch a misplaced ')' because we stop explicit search at the first ')'

        // invalid char: \x00
        contentsDescr = "A(C c)B(A a)C(uint256 v)\x00B";
        (contentsName, contentsType) = mockERC7739Utils.decodeContentsDescr(contentsDescr);
        assertEq(contentsName, "");
        assertEq(contentsType, "");
    }

    /// @notice The trailing uint16 may claim a `contentsDescr` longer than the data provided.
    /// `decodeTypedDataSig` must return empty values in that case rather than reverting or reading OOB.
    function test_decodeTypedDataSig_returnsEmpty_ifContentsDescrLengthOverflowsData() public view {
        // Sanity anchor: a well-formed blob decodes to its non-empty components, so the empty
        // result below is meaningful (not a vacuously-passing passthrough).
        bytes memory signature = new bytes(65);
        bytes32 appSeparator = keccak256("app");
        bytes32 contentsHash = keccak256("contents");
        string memory contentsDescr = "SomeType()";
        bytes memory validEncoded =
            abi.encodePacked(signature, appSeparator, contentsHash, contentsDescr, uint16(bytes(contentsDescr).length));
        (bytes memory decodedSig, bytes32 decodedSep, bytes32 decodedHash, string memory decodedDescr) =
            mockERC7739Utils.decodeTypedDataSig(validEncoded);
        assertEq(decodedSig, signature);
        assertEq(decodedSep, appSeparator);
        assertEq(decodedHash, contentsHash);
        assertEq(decodedDescr, contentsDescr);

        // 66 bytes total (64-byte body + uint16 length prefix) but the prefix claims a 1-byte
        // contentsDescr, so 66 < 66 + 1 and the declared length overflows the available data.
        bytes memory overflowEncoded = abi.encodePacked(new bytes(64), uint16(1));
        (bytes memory emptySig, bytes32 emptySep, bytes32 emptyHash, string memory emptyDescr) =
            mockERC7739Utils.decodeTypedDataSig(overflowEncoded);
        assertEq(emptySig.length, 0);
        assertEq(emptySep, bytes32(0));
        assertEq(emptyHash, bytes32(0));
        assertEq(bytes(emptyDescr).length, 0);
    }
}
