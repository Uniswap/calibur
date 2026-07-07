# IValidationHook
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/interfaces/IValidationHook.sol)

**Title:**
IValidationHook

Hook interface for optional signature validation logic

The keyHash is validated against the signature before each hook is called, but
the hookData is NOT signed over or validated within the account. It MUST be treated as unsafe and can be set by anybody.


## Functions
### afterValidateUserOp

Hook called after `validateUserOp` is called on the account by the entrypoint

The hook can revert to prevent the UserOperation from being validated.


```solidity
function afterValidateUserOp(
    bytes32 keyHash,
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 validationData,
    bytes calldata hookData
) external view returns (bytes4 selector);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyHash`|`bytes32`|the key which signed over userOpHash|
|`userOp`|`PackedUserOperation`|UserOperation|
|`userOpHash`|`bytes32`|hash of the UserOperation|
|`validationData`|`uint256`|contains data about whether or not the signature is valid and expiration information|
|`hookData`|`bytes`|any data to be passed to the hook. This has NOT been validated by the user signature|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|Must be afterValidateUserOp.selector|


### afterIsValidSignature

Hook called after verifying a signature over a digest in an EIP-1271 callback.

MUST revert to signal that validation should fail


```solidity
function afterIsValidSignature(bytes32 keyHash, bytes32 digest, bytes calldata hookData)
    external
    view
    returns (bytes4 selector);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyHash`|`bytes32`|the key which signed over digest|
|`digest`|`bytes32`|the digest to verify|
|`hookData`|`bytes`|any data to be passed to the hook.This has NOT been validated by the user signature|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|Must be afterIsValidSignature.selector|


### afterVerifySignature

Hook called after verifying a signature over `SignedBatchedCall`.

MUST revert to signal that validation should fail


```solidity
function afterVerifySignature(bytes32 keyHash, bytes32 digest, bytes calldata hookData)
    external
    view
    returns (bytes4 selector);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyHash`|`bytes32`|the key which signed over digest|
|`digest`|`bytes32`|the digest to verify|
|`hookData`|`bytes`|any data to be passed to the hook. This has NOT been validated by the user signature|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|Must be afterVerifySignature.selector|


