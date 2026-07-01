// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {CaliburEntry} from "../src/CaliburEntry.sol";

contract DeployCaliburEntry is Script {
    function setUp() public {}

    function run() public returns (CaliburEntry entry) {
        vm.startBroadcast();

        bytes32 initCodeHash = keccak256(type(CaliburEntry).creationCode);
        console2.logBytes32(initCodeHash);

        // salt 0x3b55ce071a9e4ef8dd49e65ab8ba6c747bec4c1c5b8efc95909fb463c4e53396 deploys to 0x000000005c84F8Fd50b21CAC312528A64437030e
        entry = new CaliburEntry{salt: 0x3b55ce071a9e4ef8dd49e65ab8ba6c747bec4c1c5b8efc95909fb463c4e53396}();
        console2.log("CaliburEntry", address(entry));

        vm.stopBroadcast();
    }
}
