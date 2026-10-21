# ERC7201
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/ERC7201.sol)

**Inherits:**
[IERC7201](/src/interfaces/IERC7201.sol/interface.IERC7201.md)

**Title:**
ERC-7201

Public getters for the ERC7201 calculated storage root, namespace, and version


## State Variables
### CUSTOM_STORAGE_ROOT
The calculated storage root of the contract according to ERC7201

The literal value is used in CaliburEntry.sol as it must be constant at compile time
equivalent to keccak256(abi.encode(uint256(keccak256("Uniswap.Calibur.1.0.0")) - 1)) & ~bytes32(uint256(0xff))


```solidity
bytes32 public constant CUSTOM_STORAGE_ROOT = 0x3b86514c5c56b21f08d8e56ab090292e07c2483b3e667a2a45849dcb71368600
```


## Functions
### namespaceAndVersion

Returns the namespace and version of the contract


```solidity
function namespaceAndVersion() external pure returns (string memory);
```

