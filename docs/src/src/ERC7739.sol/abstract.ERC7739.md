# ERC7739
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/ERC7739.sol)

**Title:**
ERC7739

An abstract contract that implements the ERC-7739 standard

This contract assumes that all data verified through ERC-1271 `isValidSignature` implements the defensive nested hashing scheme defined in EIP-7739

See https://eips.ethereum.org/EIPS/eip-7739


## Functions
### _callerHashMatchesReconstructedHash

Verifies that the claimed contentsHash hashed with the app's separator matches the isValidSignature provided data

This is a necessary check to ensure that the contentsHash and appSeparator provided in the signature are correct


```solidity
function _callerHashMatchesReconstructedHash(bytes32 appSeparator, bytes32 hash, bytes32 contentsHash)
    private
    pure
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`appSeparator`|`bytes32`|The app's domain separator|
|`hash`|`bytes32`|The data provided in `isValidSignature`|
|`contentsHash`|`bytes32`|The hash of the contents, i.e. hashStruct(contents)|


### _isValidTypedDataSig

Decodes the data for TypedDataSign and verifies the signature against the key over the hash

Performs the required checks per the ERC-7739 spec:
- contentsName and contentsType are not empty
- The reconstructed hash matches the hash passed in via isValidSignature


```solidity
function _isValidTypedDataSig(
    Key memory key,
    bytes32 digest,
    bytes memory domainBytes,
    bytes calldata wrappedSignature
) internal view returns (bool);
```

### _isValidNestedPersonalSig

Verifies a personal sign signature against the key over the hash


```solidity
function _isValidNestedPersonalSig(
    Key memory key,
    bytes32 digest,
    bytes32 domainSeparator,
    bytes calldata signature
) internal view returns (bool);
```

