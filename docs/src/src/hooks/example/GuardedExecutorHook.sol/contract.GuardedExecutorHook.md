# GuardedExecutorHook
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/hooks/example/GuardedExecutorHook.sol)

**Inherits:**
[IGuardedExecutorHook](/src/hooks/example/GuardedExecutorHook.sol/interface.IGuardedExecutorHook.md)

**Title:**
GuardedExecutorHook

**Author:**
modified from https://github.com/ithacaxyz/account/blob/main/src/GuardedExecutor.sol

This is an example implementation of a hook which restricts keys from executing calls
based on the target address and function selector.

For educational purposes only. This is unaudited code. Do not use this hook in production.


## State Variables
### canExecute

```solidity
mapping(AccountKeyHash => EnumerableSetLib.Bytes32Set) private canExecute
```


### ANY_KEYHASH
Represents any key hash.


```solidity
bytes32 public constant ANY_KEYHASH = 0x3232323232323232323232323232323232323232323232323232323232323232
```


### ANY_TARGET
Represents any target address.


```solidity
address public constant ANY_TARGET = 0x3232323232323232323232323232323232323232
```


### ANY_FN_SEL
Represents any function selector.


```solidity
bytes4 public constant ANY_FN_SEL = 0x32323232
```


### EMPTY_CALLDATA_FN_SEL
Represents empty calldata.
An empty calldata does not have 4 bytes for a function selector,
and we will use this special value to denote empty calldata.


```solidity
bytes4 public constant EMPTY_CALLDATA_FN_SEL = 0xe0e0e0e0
```


## Functions
### setCanExecute

Set the canExecute flag for a keyHash, to, and selector


```solidity
function setCanExecute(bytes32 keyHash, address to, bytes4 selector, bool can) external;
```

### _setCanExecute

This will hash the keyHash with the sender's account address


```solidity
function _setCanExecute(bytes32 keyHash, address to, bytes4 selector, bool can) internal;
```

### _canExecute

Returns true if the key has the required permissions to execute the call.


```solidity
function _canExecute(bytes32 keyHash, address to, bytes calldata data) public view returns (bool);
```

### beforeExecute


```solidity
function beforeExecute(bytes32 keyHash, address to, uint256, bytes calldata data)
    external
    view
    override
    returns (bytes4, bytes memory);
```

### afterExecute

This hook is a no-op.


```solidity
function afterExecute(bytes32, bool, bytes calldata, bytes calldata) external pure override returns (bytes4);
```

### _isSelfCall

Returns true if the call is to the same contract.


```solidity
function _isSelfCall(address to, bytes4) internal view returns (bool);
```

### _packCanExecute

Returns a bytes32 value that contains `to` and `selector`.


```solidity
function _packCanExecute(address to, bytes4 selector) internal pure returns (bytes32 result);
```

