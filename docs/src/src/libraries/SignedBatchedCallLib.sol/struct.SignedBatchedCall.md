# SignedBatchedCall
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/SignedBatchedCallLib.sol)


```solidity
struct SignedBatchedCall {
BatchedCall batchedCall;
uint256 nonce;
bytes32 keyHash;
address executor; // address(0) allows anyone to execute the batched call
uint256 deadline; // a deadline of 0 never expires
}
```

