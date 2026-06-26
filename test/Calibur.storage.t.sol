// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {DelegationHandler} from "./utils/DelegationHandler.sol";

contract CaliburStorageTest is DelegationHandler {
    /**
     * Calibur storage layout
     *
     * Statically-sized state variables are laid out sequentially from the custom storage root,
     * following Solidity's C3 linearization (most-base contract first), then declaration order
     * within each contract. The flattened inheritance order that contributes storage is:
     * ERC4337Account, KeyManagement, NonceManager, ERC7914, EIP712.
     *
     *
     * slot 0: uint256 _CACHED_ENTRYPOINT                                       (ERC4337Account)
     * slot 1: EnumerableSetLib.Bytes32Set keyHashes                            (KeyManagement)
     * slot 2: mapping(bytes32 keyHash => bytes encodedKey) keyStorage          (KeyManagement)
     * slot 3: mapping(bytes32 keyHash => Settings settings) keySettings        (KeyManagement)
     * slot 4: mapping(uint256 key => uint256 seq) nonceSequenceNumber          (NonceManager)
     * slot 5: mapping(address spender => uint256 allowance) _nativeAllowance   (ERC7914)
     * slot 6: bool _erc20ETHAllowanceOverridden (offset 0, 1 byte)             (ERC7914)
     *         uint96 _saltPrefix              (offset 1, 12 bytes) - packed    (EIP712)
     */
    uint256 private constant ENTRY_POINT_SLOT = 0;
    uint256 private constant KEY_HASHES_SLOT = 1;
    uint256 private constant KEY_STORAGE_SLOT = 2;
    uint256 private constant KEY_SETTINGS_SLOT = 3;
    uint256 private constant NONCE_SEQUENCE_NUMBER_SLOT = 4;
    uint256 private constant ALLOWANCE_SLOT = 5;
    uint256 private constant SALT_PREFIX_SLOT = 6;
    uint256 private constant ERC20ETH_ALLOWANCE_OVERRIDDEN_SLOT = 6;

    /// @dev Byte offsets of the two variables packed into slot 6.
    uint256 private constant ERC20ETH_ALLOWANCE_OVERRIDDEN_OFFSET = 0;
    uint256 private constant SALT_PREFIX_OFFSET = 1;

    /// @dev Must match the canonical address hardcoded in ERC7914.ERC20ETH
    address private constant ERC20ETH_ADDR = 0x00000000e20E49e6dCeE6e8283A0C090578F0fb9;

    function setUp() public {
        setUpDelegation();
    }

    function _addOffset(bytes32 slot, uint256 offset) internal pure returns (bytes32) {
        return bytes32(uint256(slot) + offset);
    }

    function _calculateNestedMappingSlot(uint256 key, bytes32 rootSlot) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, uint256(rootSlot)));
    }

    function _calculateNestedMappingSlotAddress(address addr, bytes32 rootSlot) internal pure returns (bytes32) {
        return keccak256(abi.encode(addr, uint256(rootSlot)));
    }

    /// @dev Sanity check tests for changes in namespace and version
    function test_erc7201_namespaceAndVersion() public view {
        assertEq(signerAccount.namespaceAndVersion(), "Uniswap.Calibur.1.0.0");
    }

    /// @dev Sanity check tests for changes in the calculated custom storage root
    function test_erc7201_customStorageRoot() public view {
        bytes32 customStorageRoot =
            keccak256(abi.encode(uint256(keccak256("Uniswap.Calibur.1.0.0")) - 1)) & ~bytes32(uint256(0xff));
        assertEq(signerAccount.CUSTOM_STORAGE_ROOT(), customStorageRoot);
    }

    function test_nonceSequenceNumber_nestedKey_slot() public {
        uint256 nonceKey = 1;

        vm.record();
        signerAccount.getSeq(nonceKey);
        (bytes32[] memory readSlots, bytes32[] memory writeSlots) = vm.accesses(address(signerAccount));
        assertEq(readSlots.length, 1);
        assertEq(writeSlots.length, 0);

        bytes32 mappingRootSlot = _addOffset(signerAccount.CUSTOM_STORAGE_ROOT(), NONCE_SEQUENCE_NUMBER_SLOT);
        bytes32 nestedSlot = _calculateNestedMappingSlot(nonceKey, mappingRootSlot);
        assertEq(readSlots[0], nestedSlot);
    }

    function test_allowance_nestedKey_slot() public {
        vm.record();
        signerAccount.nativeAllowance(address(0));
        (bytes32[] memory readSlots, bytes32[] memory writeSlots) = vm.accesses(address(signerAccount));
        assertEq(readSlots.length, 1);
        assertEq(writeSlots.length, 0);

        bytes32 mappingRootSlot = _addOffset(signerAccount.CUSTOM_STORAGE_ROOT(), ALLOWANCE_SLOT);
        bytes32 nestedSlot = _calculateNestedMappingSlotAddress(address(0), mappingRootSlot);
        assertEq(readSlots[0], nestedSlot);
    }

    function test_entrypoint_slot() public {
        vm.record();
        signerAccount.ENTRY_POINT();
        (bytes32[] memory readSlots, bytes32[] memory writeSlots) = vm.accesses(address(signerAccount));
        assertEq(readSlots.length, 1);
        assertEq(writeSlots.length, 0);
        assertEq(readSlots[0], _addOffset(signerAccount.CUSTOM_STORAGE_ROOT(), ENTRY_POINT_SLOT));
    }

    function test_saltPrefix_slot() public {
        bytes32 slot = _addOffset(signerAccount.CUSTOM_STORAGE_ROOT(), SALT_PREFIX_SLOT);

        vm.record();
        vm.prank(address(signerAccount));
        signerAccount.updateSalt();
        (, bytes32[] memory writeSlots) = vm.accesses(address(signerAccount));
        assertEq(writeSlots.length, 1);
        assertEq(writeSlots[0], slot);

        // _saltPrefix lives at offset 1 (bytes 1..12). updateSalt increments it from 0 to 1, so the
        // raw slot value must equal 1 shifted left past the leading offset-0 byte.
        bytes32 raw = vm.load(address(signerAccount), slot);
        assertEq(uint256(raw), uint256(1) << (8 * SALT_PREFIX_OFFSET));
    }

    /// @dev The ERC20ETH allowance override flag packs into the same slot as _saltPrefix
    function test_erc20ETHAllowanceOverridden_slot() public {
        bytes32 slot = _addOffset(signerAccount.CUSTOM_STORAGE_ROOT(), ERC20ETH_ALLOWANCE_OVERRIDDEN_SLOT);

        vm.record();
        vm.prank(address(signerAccount));
        signerAccount.approveNative(ERC20ETH_ADDR, 1 ether);
        (, bytes32[] memory writeSlots) = vm.accesses(address(signerAccount));

        bool found;
        for (uint256 i = 0; i < writeSlots.length; ++i) {
            if (writeSlots[i] == slot) found = true;
        }
        assertTrue(found);

        // _erc20ETHAllowanceOverridden lives at offset 0 (byte 0). With _saltPrefix still 0, the only
        // bit set in the slot must be the flag's low byte.
        bytes32 raw = vm.load(address(signerAccount), slot);
        assertEq(uint256(raw), uint256(1) << (8 * ERC20ETH_ALLOWANCE_OVERRIDDEN_OFFSET));
    }

    /// @dev _saltPrefix and _erc20ETHAllowanceOverridden share slot 6; writing one must change the other
    function test_saltPrefix_and_erc20ETHAllowanceOverridden_packed() public {
        bytes32 slot = _addOffset(signerAccount.CUSTOM_STORAGE_ROOT(), SALT_PREFIX_SLOT);
        // Both variables must resolve to the same storage slot.
        assertEq(SALT_PREFIX_SLOT, ERC20ETH_ALLOWANCE_OVERRIDDEN_SLOT);

        vm.startPrank(address(signerAccount));
        // Bump _saltPrefix (offset 1) to a known non-zero value.
        signerAccount.updateSalt();
        signerAccount.updateSalt();
        signerAccount.updateSalt();
        // Then set the override flag (offset 0) in the same slot.
        signerAccount.approveNative(ERC20ETH_ADDR, 1 ether);
        vm.stopPrank();

        bytes32 raw = vm.load(address(signerAccount), slot);
        // Override flag preserved in byte 0.
        assertEq(uint256(raw) & 0xff, 1);
        // _saltPrefix preserved at offset 1, unaffected by the flag write.
        assertEq(uint256(raw) >> (8 * SALT_PREFIX_OFFSET), 3);
    }
}
