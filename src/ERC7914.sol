// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC7914} from "./interfaces/IERC7914.sol";
import {BaseAuthorization} from "./BaseAuthorization.sol";

/// @title ERC-7914
/// @notice Abstract ERC-7914 implementation for native ETH approvals and transferFrom
/// @dev this ERC is not finalized and is subject to change in the future
/// https://github.com/ethereum/ERCs/blob/8380220418521ff1995445cff5ca1d0e496a3d2d/ERCS/erc-7914.md
abstract contract ERC7914 is IERC7914, BaseAuthorization {
    mapping(address spender => uint256 allowance) private _nativeAllowance;

    /// @notice Whether the account has explicitly set a native allowance for ERC20ETH
    /// @dev While false, ERC20ETH uses the default unlimited allowance; once true, the stored
    /// allowance applies. Distinguishes an explicit allowance of 0 from the unset default.
    bool private _erc20ETHAllowanceOverridden;

    /// @notice Address for ERC20ETH, a wrapper using ERC7914 for pull based native transfers
    /// @dev Uses the canonical deployment as of (https://github.com/Uniswap/ERC20-eth/blob/32b494bfed88acffdd86485f4e14b744bc634655/src/ERC20ETH.sol)
    address public constant ERC20ETH = 0x00000000e20E49e6dCeE6e8283A0C090578F0fb9;

    /// @inheritdoc IERC7914
    /// @dev Approving ERC20ETH overrides its default unlimited native allowance with `amount`,
    /// allowing the account to reduce or revoke ERC20ETH's standing ability to pull native ETH.
    function approveNative(address spender, uint256 amount) external onlyThis returns (bool) {
        if (spender == ERC20ETH) _erc20ETHAllowanceOverridden = true;
        _nativeAllowance[spender] = amount;
        emit ApproveNative(address(this), spender, amount);
        return true;
    }

    /// @inheritdoc IERC7914
    function transferFromNative(address from, address recipient, uint256 amount) external returns (bool) {
        if (amount == 0) return true;
        if (from != address(this)) revert IncorrectSender();

        // Check allowance
        uint256 currentAllowance = nativeAllowance(msg.sender);
        if (currentAllowance < amount) revert AllowanceExceeded();

        // Update allowance
        if (currentAllowance < type(uint256).max) {
            uint256 newAllowance;
            unchecked {
                newAllowance = currentAllowance - amount;
            }
            _nativeAllowance[msg.sender] = newAllowance;
            emit NativeAllowanceUpdated(msg.sender, newAllowance);
        }

        // Execute transfer
        (bool success,) = payable(recipient).call{value: amount}("");
        if (!success) revert TransferNativeFailed();

        emit TransferFromNative(address(this), recipient, amount);
        return true;
    }

    /// @inheritdoc IERC7914
    /// @dev ERC20ETH is granted an unlimited native allowance by default so it can perform pull
    /// based transfers without a prior approveNative call. Once the account has explicitly approved
    /// ERC20ETH, the stored allowance is returned instead, allowing the default to be reduced or revoked.
    function nativeAllowance(address spender) public view returns (uint256) {
        if (spender == ERC20ETH && !_erc20ETHAllowanceOverridden) return type(uint256).max;
        return _nativeAllowance[spender];
    }
}
