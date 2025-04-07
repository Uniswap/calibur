// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Key, KeyLib, KeyType} from "../../src/libraries/KeyLib.sol";
import {MinimalDelegationEntry} from "../../src/MinimalDelegationEntry.sol";
import {IMinimalDelegation} from "../../src/interfaces/IMinimalDelegation.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {TestKeyManager, TestKey} from "./TestKeyManager.sol";
import {Constants} from "./Constants.sol";
import {Settings, SettingsLib} from "../../src/libraries/SettingsLib.sol";
import {SettingsBuilder} from "./SettingsBuilder.sol";

contract DelegationHandler is Test {
    using KeyLib for Key;
    using TestKeyManager for TestKey;
    using SettingsBuilder for Settings;

    MinimalDelegationEntry public minimalDelegation;
    uint256 signerPrivateKey = 0xa11ce;
    address signer = vm.addr(signerPrivateKey);
    TestKey signerTestKey = TestKey(KeyType.Secp256k1, abi.encode(signer), signerPrivateKey);
    IMinimalDelegation public signerAccount;
    uint256 DEFAULT_KEY_EXPIRY = 10 days;

    address mockSecp256k1PublicKey = makeAddr("mockSecp256k1PublicKey");
    Key public mockSecp256k1Key = Key(KeyType.Secp256k1, abi.encode(mockSecp256k1PublicKey));
    Settings public mockSecp256k1KeySettings = SettingsBuilder.init().fromExpiration(0);

    address mockSecp256k1PublicKey2 = makeAddr("mockSecp256k1PublicKey2");
    // May need to remove block.timestamp in the future if using vm.roll / warp
    Key public mockSecp256k1Key2 = Key(KeyType.Secp256k1, abi.encode(mockSecp256k1PublicKey2));
    Settings public mockSecp256k1Key2Settings = SettingsBuilder.init().fromExpiration(uint40(block.timestamp + 3600));

    EntryPoint public entryPoint;

    function setUpDelegation() public {
        minimalDelegation = new MinimalDelegationEntry();
        _delegate(signer, address(minimalDelegation));
        signerAccount = IMinimalDelegation(signer);

        vm.etch(Constants.ENTRY_POINT_V_0_8, Constants.ENTRY_POINT_V_0_8_CODE);
        vm.label(Constants.ENTRY_POINT_V_0_8, "EntryPoint");

        entryPoint = EntryPoint(payable(Constants.ENTRY_POINT_V_0_8));
    }

    function _delegate(address _signer, address _implementation) internal {
        vm.etch(_signer, bytes.concat(hex"ef0100", abi.encodePacked(_implementation)));
        require(_signer.code.length > 0, "signer not delegated");
    }
}
