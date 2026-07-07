# ERC7821
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/ERC7821.sol)

**Inherits:**
[IERC7821](/src/interfaces/IERC7821.sol/interface.IERC7821.md)

**Title:**
ERC7821

A base contract that implements the ERC7821 interface

This contract supports only the Single Batch mode defined in the specification. See IERC7821.supportsExecutionMode() for more details.
We do NOT support the following ERC-7821 execution modes:
- `0x01000000000078210001...`: Single batch with optional `opData`.
- `0x01000000000078210002...`: Batch of batches


## Functions
### supportsExecutionMode

Provided for execution mode support detection.


```solidity
function supportsExecutionMode(bytes32 mode) external pure override returns (bool result);
```

