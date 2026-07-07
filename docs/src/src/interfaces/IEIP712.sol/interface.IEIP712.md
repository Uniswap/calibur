# IEIP712
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/interfaces/IEIP712.sol)

**Title:**
IEIP712


## Functions
### domainBytes

Encode the EIP-5267 domain into bytes

for use in ERC-7739


```solidity
function domainBytes() external view returns (bytes memory);
```

### domainSeparator

Returns the `domainSeparator` used to create EIP-712 compliant hashes.


```solidity
function domainSeparator() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The 32 bytes domain separator result.|


### hashTypedData

Public getter for `_hashTypedData()` to produce a EIP-712 hash using this account's domain separator


```solidity
function hashTypedData(bytes32 hash) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`bytes32`|The nested typed data. Assumes the hash is the result of applying EIP-712 `hashStruct`.|


### updateSalt

Increment the EIP-712 domain salt prefix, the upper 96 bits of the salt
12 bytes | 20 bytes
prefix   | Implementation address (immutable, set on deployment)

Use this to invalidate existing signatures signed under the old domain separator.


```solidity
function updateSalt() external;
```

