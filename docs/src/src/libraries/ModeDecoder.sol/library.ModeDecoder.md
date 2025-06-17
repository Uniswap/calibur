# ModeDecoder
[Git Source](https://github.com/Uniswap/minimal-delegation/blob/8189d62a80ed3ac2bd308849641dca52350f024a/src/libraries/ModeDecoder.sol)

Decodes a bytes32 mode as specified in ERC-7821 and ERC-7579.

*This library only supports two modes: BATCHED_CALL and BATCHED_CAN_REVERT_CALL.*


## State Variables
### BATCHED_CALL

```solidity
bytes32 constant BATCHED_CALL = 0x0100000000000000000000000000000000000000000000000000000000000000;
```


### BATCHED_CAN_REVERT_CALL

```solidity
bytes32 constant BATCHED_CAN_REVERT_CALL = 0x0101000000000000000000000000000000000000000000000000000000000000;
```


### EXTRACT_EXEC_TYPE

```solidity
bytes32 constant EXTRACT_EXEC_TYPE = 0x00ff000000000000000000000000000000000000000000000000000000000000;
```


## Functions
### isBatchedCall


```solidity
function isBatchedCall(bytes32 mode) internal pure returns (bool);
```

### revertOnFailure


```solidity
function revertOnFailure(bytes32 mode) internal pure returns (bool);
```

