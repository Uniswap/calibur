# HooksLib
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/HooksLib.sol)

**Title:**
HooksLib

**Author:**
Inspired by https://github.com/Uniswap/v4-core/blob/main/src/libraries/Hooks.sol

Hooks are invoked by inspecting the least significant bits of the address it is deployed to
For example, a hook deployed to address: 0x000000000000000000000000000000000000000a
has the lowest bits '1010' which would cause the `afterValidateUserOp`, and `beforeExecute` hooks to be used.


## State Variables
### AFTER_VERIFY_SIGNATURE_FLAG
Internal constant hook flags


```solidity
uint160 internal constant AFTER_VERIFY_SIGNATURE_FLAG = 1 << 0
```


### AFTER_VALIDATE_USER_OP_FLAG

```solidity
uint160 internal constant AFTER_VALIDATE_USER_OP_FLAG = 1 << 1
```


### AFTER_IS_VALID_SIGNATURE_FLAG

```solidity
uint160 internal constant AFTER_IS_VALID_SIGNATURE_FLAG = 1 << 2
```


### BEFORE_EXECUTE_FLAG

```solidity
uint160 internal constant BEFORE_EXECUTE_FLAG = 1 << 3
```


### AFTER_EXECUTE_FLAG

```solidity
uint160 internal constant AFTER_EXECUTE_FLAG = 1 << 4
```


### ALL_FLAGS
Bitmask of every defined hook flag


```solidity
uint160 internal constant ALL_FLAGS = AFTER_VERIFY_SIGNATURE_FLAG | AFTER_VALIDATE_USER_OP_FLAG
    | AFTER_IS_VALID_SIGNATURE_FLAG | BEFORE_EXECUTE_FLAG | AFTER_EXECUTE_FLAG
```


## Functions
### hasPermission

Returns whether the flag is configured for the hook


```solidity
function hasPermission(IHook self, uint160 flag) internal pure returns (bool);
```

### handleAfterValidateUserOp

Handles the afterValidateUserOp hook

MAY revert if desired according to ERC-4337 spec

Expected to validate the userOp and return a validationData which will override the internally computed validationData


```solidity
function handleAfterValidateUserOp(
    IHook self,
    bytes32 keyHash,
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 validationData,
    bytes memory hookData
) internal view;
```

### handleAfterIsValidSignature

Handles the afterIsValidSignature hook

MUST revert if validation fails

Expected to validate the signature and return a value which will override the internally computed ERC-1271 magic value


```solidity
function handleAfterIsValidSignature(IHook self, bytes32 keyHash, bytes32 digest, bytes memory hookData)
    internal
    view;
```

### handleAfterVerifySignature

Handles the afterVerifySignature hook

MUST revert if validation fails


```solidity
function handleAfterVerifySignature(IHook self, bytes32 keyHash, bytes32 digest, bytes memory hookData)
    internal
    view;
```

### handleBeforeExecute

Handles the beforeExecute hook

Expected to revert if the execution should be reverted


```solidity
function handleBeforeExecute(IHook self, bytes32 keyHash, address to, uint256 value, bytes memory data)
    internal
    returns (bytes memory beforeExecuteData);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`beforeExecuteData`|`bytes`|any data which the hook wishes to be passed into the afterExecute hook|


### handleAfterExecute

Handles the afterExecute hook

Expected to revert if the execution should be reverted


```solidity
function handleAfterExecute(
    IHook self,
    bytes32 keyHash,
    bool success,
    bytes memory output,
    bytes memory beforeExecuteData
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`self`|`IHook`||
|`keyHash`|`bytes32`||
|`success`|`bool`||
|`output`|`bytes`||
|`beforeExecuteData`|`bytes`|data returned from the beforeExecute hook|


## Errors
### InvalidHookResponse
Hook did not return its selector


```solidity
error InvalidHookResponse();
```

