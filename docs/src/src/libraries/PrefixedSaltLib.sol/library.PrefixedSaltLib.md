# PrefixedSaltLib
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/PrefixedSaltLib.sol)

**Title:**
PrefixedSaltLib

A library for packing and updating the salt with a prefix for EIP-712 domain separators


## Functions
### pack

Pack the prefix and implementation address into a bytes32


```solidity
function pack(uint96 prefix, address implementation) internal pure returns (bytes32);
```

