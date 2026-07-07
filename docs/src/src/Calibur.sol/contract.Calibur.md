# Calibur
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/Calibur.sol)

**Inherits:**
[ICalibur](/src/interfaces/ICalibur.sol/interface.ICalibur.md), [ERC7821](/src/ERC7821.sol/abstract.ERC7821.md), [ERC1271](/src/ERC1271.sol/abstract.ERC1271.md), [ERC4337Account](/src/ERC4337Account.sol/abstract.ERC4337Account.md), [KeyManagement](/src/KeyManagement.sol/abstract.KeyManagement.md), [NonceManager](/src/NonceManager.sol/abstract.NonceManager.md), [ERC7914](/src/ERC7914.sol/abstract.ERC7914.md), [ERC7201](/src/ERC7201.sol/contract.ERC7201.md), [ERC7739](/src/ERC7739.sol/abstract.ERC7739.md), [EIP712](/src/EIP712.sol/contract.EIP712.md), Receiver

**Title:**
Calibur

A singleton contract wallet supporting batched transactions, alternative signers, and native ETH transferFrom

Delegate to Calibur from an EOA using EIP-7702

**Note:**
security-contact: security@uniswap.org


## Functions
### execute

Execute entrypoint for trusted callers

This function is only callable by this account or an admin key


```solidity
function execute(BatchedCall memory batchedCall) public payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchedCall`|`BatchedCall`|The batched call to execute|


### execute

Execute entrypoint for relayed batched calls


```solidity
function execute(SignedBatchedCall calldata signedBatchedCall, bytes calldata wrappedSignature) public payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`signedBatchedCall`|`SignedBatchedCall`|The signed batched call to execute|
|`wrappedSignature`|`bytes`|The signature along with any optional hook data, equivalent to abi.encode(bytes, bytes)|


### execute

Executes a batched call.


```solidity
function execute(bytes32 mode, bytes calldata executionData) external payable override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mode`|`bytes32`|The mode to execute the batched call in.|
|`executionData`|`bytes`|The data to execute the batched call with.|


### executeUserOp

This function is executeable only by the EntryPoint contract, and is the main pathway for UserOperations to be executed.

UserOperations can be executed through the execute function, but another method of authorization (ie through a passed in signature) is required.
`userOp.callData` is `abi.encodeCall(IAccountExecute.executeUserOp.selector, (abi.encode(Call[]), bool))`
Note that this contract is only compatible with Entrypoint versions v0.7.0 and v0.8.0.
It is not compatible with v0.6.0, as that version does not support the "executeUserOp" selector.


```solidity
function executeUserOp(PackedUserOperation calldata userOp, bytes32) external onlyEntryPoint;
```

### validateUserOp

Validate user's signature and nonce
the entryPoint will make the call to the recipient only if this validation call returns successfully.
signature failure should be reported by returning SIG_VALIDATION_FAILED (1).
This allows making a "simulation call" without a valid signature
Other failures (e.g. nonce mismatch, or invalid signature format) should still revert to signal failure.

Only return validationData if the signature from the key associated with `keyHash` is valid over the userOpHash
- The ERC-4337 spec requires that `validateUserOp` does not early return if the signature is invalid such that accurate gas estimation can be done


```solidity
function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
    external
    onlyEntryPoint
    returns (uint256 validationData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userOp`|`PackedUserOperation`|             - The operation that is about to be executed.|
|`userOpHash`|`bytes32`|         - Hash of the user's request data. can be used as the basis for signature.|
|`missingAccountFunds`|`uint256`|- Missing funds on the account's deposit in the entrypoint. This is the minimum amount to transfer to the sender(entryPoint) to be able to make the call. The excess is left as a deposit in the entrypoint for future calls. Can be withdrawn anytime using "entryPoint.withdrawTo()". In case there is a paymaster in the request (or the current deposit is high enough), this value will be zero.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`validationData`|`uint256`|is (uint256(validAfter) << (160 + 48)) | (uint256(validUntil) << 160) | (isValid ? 0 : 1) - `validAfter` is always 0.|


### isValidSignature


```solidity
function isValidSignature(bytes32 digest, bytes calldata wrappedSignature)
    public
    view
    override(ERC1271, IERC1271)
    returns (bytes4);
```

### _checkCanRegister

Prevent registering protected addresses as keys on the account


```solidity
function _checkCanRegister(Key memory key) internal view override;
```

### _processBatch

Iterates through calls, reverting according to specified failure mode


```solidity
function _processBatch(BatchedCall memory batchedCall, bytes32 keyHash) private;
```

### _process

Executes a low level call using execution hooks if set


```solidity
function _process(Call memory _call, bytes32 keyHash) private returns (bool success, bytes memory output);
```

### _handleVerifySignature

This function is used to handle the verification of signatures sent through execute()


```solidity
function _handleVerifySignature(SignedBatchedCall calldata signedBatchedCall, bytes calldata wrappedSignature)
    private;
```

### _senderIsExecutor

Returns true if the msg.sender is the executor or if the executor is address(0)


```solidity
function _senderIsExecutor(address executor) private view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`executor`|`address`|The address of the allowed executor of the signed batched call|


