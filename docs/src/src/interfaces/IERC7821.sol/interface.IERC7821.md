# IERC7821
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/interfaces/IERC7821.sol)


## Functions
### execute

Executes a batched call.

The mode is checked with strict equality in the implementation and only supports two mode types.


```solidity
function execute(bytes32 mode, bytes calldata executionData) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mode`|`bytes32`|The mode to execute the batched call in.|
|`executionData`|`bytes`|The data to execute the batched call with.|


### supportsExecutionMode

Provided for execution mode support detection.

This returns true for the BATCHED_CALL "0x010...00" and BATCHED_CALL_CAN_REVERT "0x01010...00" modes.


```solidity
function supportsExecutionMode(bytes32 mode) external view returns (bool result);
```

## Errors
### UnsupportedExecutionMode
Thrown when an unsupported execution mode is provided.


```solidity
error UnsupportedExecutionMode();
```

