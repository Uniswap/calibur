# IERC4337Account
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/interfaces/IERC4337Account.sol)

**Inherits:**
IAccount

**Title:**
IERC4337Account Interface

Interface for contracts that support updating the EntryPoint contract

Extends the IAccount interface from the ERC4337 specification


## Functions
### updateEntryPoint

Updates the EntryPoint address

4337 support is enabled by default, so this must be called with address(0) in order to disable it.


```solidity
function updateEntryPoint(address entryPoint) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`entryPoint`|`address`|The new EntryPoint address|


### ENTRY_POINT

Returns the address of the EntryPoint contract that this account uses


```solidity
function ENTRY_POINT() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the EntryPoint contract|


## Events
### EntryPointUpdated
Emitted when the EntryPoint address is updated


```solidity
event EntryPointUpdated(address indexed newEntryPoint);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newEntryPoint`|`address`|The new EntryPoint address|

## Errors
### NotEntryPoint
Thrown when the caller to validateUserOp is not the EntryPoint contract


```solidity
error NotEntryPoint();
```

