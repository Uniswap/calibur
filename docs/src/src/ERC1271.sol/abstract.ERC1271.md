# ERC1271
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/ERC1271.sol)

**Inherits:**
[IERC1271](/src/interfaces/IERC1271.sol/interface.IERC1271.md)

**Title:**
ERC-1271

Abstract ERC1271 implementation which supports nested EIP-712 workflows as defined by ERC-7739


## State Variables
### _1271_MAGIC_VALUE
The magic value returned by `isValidSignature()` if the signature is valid.


```solidity
bytes4 internal constant _1271_MAGIC_VALUE = 0x1626ba7e
```


### _1271_INVALID_VALUE
The magic value returned by `isValidSignature()` if the signature is invalid.


```solidity
bytes4 internal constant _1271_INVALID_VALUE = 0xffffffff
```


## Functions
### isValidSignature

Validates the `signature` against the given `hash`.

Supports the following signature workflows:
- 64 or 65-byte ECDSA signatures from address(this)
- Nested typed data signatures as defined by ERC-7739
- Nested personal signatures as defined by ERC-7739


```solidity
function isValidSignature(bytes32 hash, bytes calldata signature) public view virtual returns (bytes4);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|result `0x1626ba7e` if validation succeeded, else `0xffffffff`.|


