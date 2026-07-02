# IERC7914
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/interfaces/IERC7914.sol)

**Title:**
IERC7914


## Functions
### nativeAllowance

Returns the allowance of a spender


```solidity
function nativeAllowance(address spender) external view returns (uint256);
```

### transferFromNative

Transfers native tokens from the caller to a recipient

Doesn't forward transferFrom requests - the specified `from` address must be address(this)


```solidity
function transferFromNative(address from, address recipient, uint256 amount) external returns (bool);
```

### approveNative

Approves a spender to transfer native tokens on behalf of the caller


```solidity
function approveNative(address spender, uint256 amount) external returns (bool);
```

## Events
### TransferFromNative
Emitted when a transfer from native is made


```solidity
event TransferFromNative(address indexed from, address indexed to, uint256 value);
```

### ApproveNative
Emitted when a native approval is made


```solidity
event ApproveNative(address indexed owner, address indexed spender, uint256 value);
```

### NativeAllowanceUpdated
Emitted when the native allowance of a spender is updated when a transfer happens


```solidity
event NativeAllowanceUpdated(address indexed spender, uint256 value);
```

## Errors
### AllowanceExceeded
Thrown when the caller's allowance is exceeded when transferring


```solidity
error AllowanceExceeded();
```

### IncorrectSender
Thrown when the sender is not the expected one


```solidity
error IncorrectSender();
```

### TransferNativeFailed
Thrown when the transfer of native tokens fails


```solidity
error TransferNativeFailed();
```

