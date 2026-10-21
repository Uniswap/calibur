# SignedBatchedCallLib
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/SignedBatchedCallLib.sol)

**Title:**
SignedBatchedCallLib

Library for EIP-712 hashing of SignedBatchedCall


## State Variables
### SIGNED_BATCHED_CALL_TYPE
The type string for the SignedBatchedCall struct


```solidity
bytes internal constant SIGNED_BATCHED_CALL_TYPE =
    "SignedBatchedCall(BatchedCall batchedCall,uint256 nonce,bytes32 keyHash,address executor,uint256 deadline)BatchedCall(Call[] calls,bool revertOnFailure)Call(address to,uint256 value,bytes data)"
```


### SIGNED_BATCHED_CALL_TYPEHASH
The typehash for the SignedBatchedCall struct


```solidity
bytes32 internal constant SIGNED_BATCHED_CALL_TYPEHASH = keccak256(SIGNED_BATCHED_CALL_TYPE)
```


## Functions
### hash

Hashes a SignedBatchedCall struct.


```solidity
function hash(SignedBatchedCall memory signedBatchedCall) internal pure returns (bytes32);
```

