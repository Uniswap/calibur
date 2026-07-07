# ERC4337Account
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/ERC4337Account.sol)

**Inherits:**
[IERC4337Account](/src/interfaces/IERC4337Account.sol/interface.IERC4337Account.md), [BaseAuthorization](/src/BaseAuthorization.sol/contract.BaseAuthorization.md)

**Title:**
ERC4337Account

A base contract which allows for the entrypoint to have a default value that can be updated


## State Variables
### SIG_VALIDATION_SUCCEEDED
ERC-4337 defined constants


```solidity
uint256 internal constant SIG_VALIDATION_SUCCEEDED = 0
```


### SIG_VALIDATION_FAILED

```solidity
uint256 internal constant SIG_VALIDATION_FAILED = 1
```


### _CACHED_ENTRYPOINT
The cached entrypoint address


```solidity
uint256 internal _CACHED_ENTRYPOINT
```


## Functions
### onlyEntryPoint


```solidity
modifier onlyEntryPoint() ;
```

### updateEntryPoint

Updates the EntryPoint address

4337 support is enabled by default, so this must be called with address(0) in order to disable it.


```solidity
function updateEntryPoint(address entryPoint) external onlyThis;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`entryPoint`|`address`|The new EntryPoint address|


### ENTRY_POINT

Returns the address of the EntryPoint contract that this account uses


```solidity
function ENTRY_POINT() public view override returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the EntryPoint contract|


### _payEntryPoint


```solidity
function _payEntryPoint(uint256 missingAccountFunds) internal;
```

