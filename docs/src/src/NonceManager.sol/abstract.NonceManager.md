# NonceManager
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/NonceManager.sol)

**Inherits:**
[INonceManager](/src/interfaces/INonceManager.sol/interface.INonceManager.md), [BaseAuthorization](/src/BaseAuthorization.sol/contract.BaseAuthorization.md)

**Title:**
NonceManager

A contract that manages nonces to prevent replay attacks


## State Variables
### nonceSequenceNumber

```solidity
mapping(uint256 key => uint256 seq) public nonceSequenceNumber
```


## Functions
### invalidateNonce

Invalidates all sequence numbers for a given key up to but not including the provided sequence number in the nonce


```solidity
function invalidateNonce(uint256 newNonce) external onlyThis;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newNonce`|`uint256`|The new nonce to set. Invalidates all sequence numbers for the key less than it.|


### getSeq

Returns the next valid sequence number for a given key


```solidity
function getSeq(uint256 key) external view override returns (uint256 seq);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`key`|`uint256`|The sequence key, passed as uint256 but only 192 bits are used.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`seq`|`uint256`|The sequence number padded to 256 bits but only the lower 64 bits should be used.|


### _useNonce

Validates that the provided nonce is valid and increments the sequence number

If valid, increments the sequence number for future nonce validations


```solidity
function _useNonce(uint256 nonce) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nonce`|`uint256`|A 256-bit value where: - Upper 192 bits: the sequence key - Lower 64 bits: must match the expected sequence number for the key|


