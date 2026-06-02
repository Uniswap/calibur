// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC7914} from "./interfaces/IERC7914.sol";
import {TransientNativeAllowance} from "./libraries/TransientNativeAllowance.sol";
import {BaseAuthorization} from "./BaseAuthorization.sol";

/// @title ERC-7914
/// @notice Abstract ERC-7914 implementation with support for transient allowances
/// @dev this ERC is not finalized and is subject to change in the future
/// https://github.com/ethereum/ERCs/blob/8380220418521ff1995445cff5ca1d0e496a3d2d/ERCS/erc-7914.md
abstract contract ERC7914 is IERC7914, BaseAuthorization {
    mapping(address spender => uint256 allowance) private _nativeAllowance;

    /// @notice Address for ERC20ETH, a wrapper using ERC7914 for pull based native transfers
    /// @dev Uses the canonical deployment as of (https://github.com/Uniswap/ERC20-eth/blob/32b494bfed88acffdd86485f4e14b744bc634655/src/ERC20ETH.sol)
    address public constant ERC20ETH = 0x00000000e20E49e6dCeE6e8283A0C090578F0fb9;

    /// @inheritdoc IERC7914
    /// @dev This does NOT override approvals for the ERC20ETH contract
    function approveNative(address spender, uint256 amount) external onlyThis returns (bool) {
        _nativeAllowance[spender] = amount;
        emit ApproveNative(address(this), spender, amount);
        return true;
    }

    /// @inheritdoc IERC7914
    function approveNativeTransient(address spender, uint256 amount) external onlyThis returns (bool) {
        TransientNativeAllowance.set(spender, amount);
        emit ApproveNativeTransient(address(this), spender, amount);
        return true;
    }

    /// @inheritdoc IERC7914
    function transferFromNative(address from, address recipient, uint256 amount) external returns (bool) {
        if (amount == 0) return true;
        _transferFrom(from, recipient, amount, false);
        emit TransferFromNative(address(this), recipient, amount);
        return true;
    }

    /// @inheritdoc IERC7914
    function transferFromNativeTransient(address from, address recipient, uint256 amount) external returns (bool) {
        if (amount == 0) return true;
        _transferFrom(from, recipient, amount, true);
        emit TransferFromNativeTransient(address(this), recipient, amount);
        return true;
    }

    /// @inheritdoc IERC7914
    /// @dev This contract automatically approves ERC20ETH for persistent native transfers
    function nativeAllowance(address spender) public view returns (uint256) {
        if (spender == ERC20ETH) return type(uint256).max;
        return _nativeAllowance[spender];
    }

    /// @inheritdoc IERC7914
    function transientNativeAllowance(address spender) public view returns (uint256) {
        return TransientNativeAllowance.get(spender);
    }

    /// @dev Internal function to validate and execute transfers
    /// @param from The address to transfer from
    /// @param recipient The address to receive the funds
    /// @param amount The amount to transfer
    /// @param isTransient Whether this is transient allowance or not
    function _transferFrom(address from, address recipient, uint256 amount, bool isTransient) internal {
        // Validate inputs
        if (from != address(this)) revert IncorrectSender();

        // Check allowance
        uint256 currentAllowance = isTransient ? transientNativeAllowance(msg.sender) : nativeAllowance(msg.sender);
        if (currentAllowance < amount) revert AllowanceExceeded();

        // Update allowance
        if (currentAllowance < type(uint256).max) {
            uint256 newAllowance;
            unchecked {
                newAllowance = currentAllowance - amount;
            }
            if (isTransient) {
                TransientNativeAllowance.set(msg.sender, newAllowance);
            } else {
                _nativeAllowance[msg.sender] = newAllowance;
                emit NativeAllowanceUpdated(msg.sender, newAllowance);
            }
        }

        // Execute transfer
        (bool success,) = payable(recipient).call{value: amount}("");
        if (!success) {
            revert TransferNativeFailed();
        }
    }
}
