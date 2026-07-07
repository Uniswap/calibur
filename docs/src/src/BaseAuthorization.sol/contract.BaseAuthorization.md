# BaseAuthorization
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/BaseAuthorization.sol)

**Title:**
BaseAuthorization

A base contract that provides a modifier to restrict access to the contract itself


## Functions
### onlyThis

A modifier that restricts access to the contract itself


```solidity
modifier onlyThis() ;
```

## Errors
### Unauthorized
An error that is thrown when an unauthorized address attempts to call a function


```solidity
error Unauthorized();
```

