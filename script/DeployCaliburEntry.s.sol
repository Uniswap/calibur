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

        // salt 0x8e5c26fd60c5a1cd7b23cbb635c1176880b2eb8b2f88b7fa14cb35057a8d44eb deploys to 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6
        entry = new CaliburEntry{salt: 0x8e5c26fd60c5a1cd7b23cbb635c1176880b2eb8b2f88b7fa14cb35057a8d44eb}();
        console2.log("CaliburEntry", address(entry));

        vm.stopBroadcast();
    }
}
