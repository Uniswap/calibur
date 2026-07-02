# CalldataDecoder
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/CalldataDecoder.sol)

**Title:**
CalldataDecoder


## State Variables
### OFFSET_OR_LENGTH_MASK
mask used for offsets and lengths to ensure no overflow

no sane abi encoding will pass in an offset or length greater than type(uint32).max
(note that this does deviate from standard solidity behavior and offsets/lengths will
be interpreted as mod type(uint32).max which will only impact malicious/buggy callers)


```solidity
uint256 constant OFFSET_OR_LENGTH_MASK = 0xffffffff
```


### SLICE_ERROR_SELECTOR
error SliceOutOfBounds();


```solidity
uint256 constant SLICE_ERROR_SELECTOR = 0x3b99b53d
```


## Functions
### removeSelector

Removes the selector from the calldata and returns the encoded params.


```solidity
function removeSelector(bytes calldata data) internal pure returns (bytes calldata params);
```

### toBytes

Decode the `_arg`-th element in `_bytes` as `bytes`

Performs a length check, returning empty bytes if it fails. This MUST be checked by the caller.


```solidity
function toBytes(bytes calldata _bytes, uint256 _arg) internal pure returns (bytes calldata res);
```

### safeToBytes

Decode the `_arg`-th element in `_bytes` as `bytes`

Reverts if the length is not what the encoding is expecting


```solidity
function safeToBytes(bytes calldata _bytes, uint256 _arg) internal pure returns (bytes calldata res);
```

