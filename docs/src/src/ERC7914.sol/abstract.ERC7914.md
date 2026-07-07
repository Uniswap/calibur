# ERC7914
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/ERC7914.sol)

**Inherits:**
[IERC7914](/src/interfaces/IERC7914.sol/interface.IERC7914.md), [BaseAuthorization](/src/BaseAuthorization.sol/contract.BaseAuthorization.md)

**Title:**
ERC-7914

Abstract ERC-7914 implementation for native ETH approvals and transferFrom

this ERC is not finalized and is subject to change in the future
https://github.com/ethereum/ERCs/blob/8380220418521ff1995445cff5ca1d0e496a3d2d/ERCS/erc-7914.md


## State Variables
### _nativeAllowance

```solidity
mapping(address spender => uint256 allowance) private _nativeAllowance
```


### _erc20ETHAllowanceOverridden
Whether the account has explicitly set a native allowance for ERC20ETH

While false, ERC20ETH uses the default unlimited allowance; once true, the stored
allowance applies. Distinguishes an explicit allowance of 0 from the unset default.


```solidity
bool private _erc20ETHAllowanceOverridden
```


### ERC20ETH
Address for ERC20ETH, a wrapper using ERC7914 for pull based native transfers

Uses the canonical deployment as of (https://github.com/Uniswap/ERC20-eth/blob/32b494bfed88acffdd86485f4e14b744bc634655/src/ERC20ETH.sol)


```solidity
address public constant ERC20ETH = 0x00000000e20E49e6dCeE6e8283A0C090578F0fb9
```


## Functions
### approveNative

Approves a spender to transfer native tokens on behalf of the caller

Approving ERC20ETH overrides its default unlimited native allowance with `amount`,
allowing the account to reduce or revoke ERC20ETH's standing ability to pull native ETH.


```solidity
function approveNative(address spender, uint256 amount) external onlyThis returns (bool);
```

### transferFromNative

Transfers native tokens from the caller to a recipient

Doesn't forward transferFrom requests - the specified `from` address must be address(this)


```solidity
function transferFromNative(address from, address recipient, uint256 amount) external returns (bool);
```

### nativeAllowance

Returns the allowance of a spender

ERC20ETH is granted an unlimited native allowance by default so it can perform pull
based transfers without a prior approveNative call. Once the account has explicitly approved
ERC20ETH, the stored allowance is returned instead, allowing the default to be reduced or revoked.


```solidity
function nativeAllowance(address spender) public view returns (uint256);
```

