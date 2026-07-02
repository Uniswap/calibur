# INonceManager
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/interfaces/INonceManager.sol)

**Title:**
INonceManager

Interface for managing nonces used to prevent replay attacks

Each nonce consists of a 192-bit key and 64-bit sequence number
The key allows multiple independent nonce sequences
The sequence must be used in order (0, 1, 2, etc) for each key


## Functions
### getSeq

Returns the next valid sequence number for a given key


```solidity
function getSeq(uint256 key) external view returns (uint256 seq);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`key`|`uint256`|The sequence key, passed as uint256 but only 192 bits are used.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`seq`|`uint256`|The sequence number padded to 256 bits but only the lower 64 bits should be used.|


### invalidateNonce

Invalidates all sequence numbers for a given key up to but not including the provided sequence number in the nonce


```solidity
function invalidateNonce(uint256 newNonce) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newNonce`|`uint256`|The new nonce to set. Invalidates all sequence numbers for the key less than it.|


## Events
### NonceInvalidated
The event emitted when a nonce is invalidated


```solidity
event NonceInvalidated(uint256 nonce);
```

## Errors
### InvalidNonce
The error emitted when a nonce is invalid


```solidity
error InvalidNonce();
```

### ExcessiveInvalidation
The error emitted when too many nonces are invalidated in one transaction


```solidity
error ExcessiveInvalidation();
```

