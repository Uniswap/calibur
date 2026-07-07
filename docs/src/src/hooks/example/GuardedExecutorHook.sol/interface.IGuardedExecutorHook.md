# IGuardedExecutorHook
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/hooks/example/GuardedExecutorHook.sol)

**Inherits:**
[IExecutionHook](/src/interfaces/IExecutionHook.sol/interface.IExecutionHook.md)


## Functions
### ANY_KEYHASH

Sentinel value which represents any key hash.


```solidity
function ANY_KEYHASH() external view returns (bytes32);
```

### ANY_TARGET

Sentinel value which represents any target address.


```solidity
function ANY_TARGET() external view returns (address);
```

### ANY_FN_SEL

Sentinel value which represents any function selector.


```solidity
function ANY_FN_SEL() external view returns (bytes4);
```

### setCanExecute

Set the canExecute flag for a keyHash, to, and selector.

Note that this hook does not support restricting any `value` sent along with the call


```solidity
function setCanExecute(bytes32 keyHash, address to, bytes4 selector, bool can) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyHash`|`bytes32`|the bytes32 keyHash|
|`to`|`address`|the target address|
|`selector`|`bytes4`|the function selector|
|`can`|`bool`|flag to set|


## Errors
### Unauthorized
Thrown when a key is not authorized to execute a call.


```solidity
error Unauthorized();
```

### SelfCallNotAllowed
Thrown when a self call is not allowed.


```solidity
error SelfCallNotAllowed();
```

