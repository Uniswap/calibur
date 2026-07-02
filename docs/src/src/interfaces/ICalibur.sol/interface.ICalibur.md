# ICalibur
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/interfaces/ICalibur.sol)

**Inherits:**
[IKeyManagement](/src/interfaces/IKeyManagement.sol/interface.IKeyManagement.md), [IERC4337Account](/src/interfaces/IERC4337Account.sol/interface.IERC4337Account.md), [IERC7821](/src/interfaces/IERC7821.sol/interface.IERC7821.md), [IERC1271](/src/interfaces/IERC1271.sol/interface.IERC1271.md), [IEIP712](/src/interfaces/IEIP712.sol/interface.IEIP712.md), IERC5267, [IERC7201](/src/interfaces/IERC7201.sol/interface.IERC7201.md), [IERC7914](/src/interfaces/IERC7914.sol/interface.IERC7914.md), [INonceManager](/src/interfaces/INonceManager.sol/interface.INonceManager.md)

A non-upgradeable contract that can be delegated to with a 7702 delegation transaction.
This implementation supports:
ERC-4337 relayable userOps, with version v0.8.0 of the Entrypoint contract.
ERC-7821 batched actions
EIP-712 typed data signature verification
ERC-7201 compliant storage use
ERC-1271 compliant signature verification
ERC-7914 transfer from native
Alternative key management and verification


## Functions
### execute

Execute entrypoint for trusted callers

This function is only callable by this account or an admin key


```solidity
function execute(BatchedCall memory batchedCall) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchedCall`|`BatchedCall`|The batched call to execute|


### execute

Execute entrypoint for relayed batched calls


```solidity
function execute(SignedBatchedCall memory signedBatchedCall, bytes memory wrappedSignature) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signedBatchedCall`|`SignedBatchedCall`|The signed batched call to execute|
|`wrappedSignature`|`bytes`|The signature along with any optional hook data, equivalent to abi.encode(bytes, bytes)|


## Errors
### CallFailed
Generic error to bubble up errors from batched calls


```solidity
error CallFailed(bytes reason);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reason`|`bytes`|The revert data from the inner call|

### InvalidSignature
Used when internally verifying signatures over batched calls


```solidity
error InvalidSignature();
```

### SignatureExpired
Thrown when the signature has expired


```solidity
error SignatureExpired();
```

