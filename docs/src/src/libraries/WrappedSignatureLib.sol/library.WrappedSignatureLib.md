# WrappedSignatureLib
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/WrappedSignatureLib.sol)

**Title:**
WrappedSignatureLib

A library for handling signatures with different wrapping schemes


## State Variables
### INVALID_SIGNATURE_LENGTH_SELECTOR
error InvalidSignatureLength();


```solidity
uint256 constant INVALID_SIGNATURE_LENGTH_SELECTOR = 0x4be6321b
```


## Functions
### isEmpty

Returns true if the signature is empty

For use in the ERC-7739 sentinel value check


```solidity
function isEmpty(bytes calldata data) internal pure returns (bool);
```

### isRawSignature

Returns true for standard or compact length ECDSA signatures

will also return true for standard p256 signatures however those MUST be wrapped with extra information in the verify sig flow


```solidity
function isRawSignature(bytes calldata data) internal pure returns (bool);
```

### decodeWithHookData

Decode the signature and hook data from the calldata

The calldata is expected to be encoded as `abi.encode(bytes signature, bytes hookData)`
If the length of the data does not match the encoded length the function will revert with `SliceOutOfBounds()`
Also, if the signature is less than 64 bytes, it will revert with `InvalidSignatureLength()`


```solidity
function decodeWithHookData(bytes calldata data)
    internal
    pure
    returns (bytes calldata signature, bytes calldata hookData);
```

### decodeWithKeyHashAndHookData

Decode the keyHash, signature, and hook data from the calldata

The calldata is expected to be encoded as `abi.encode(bytes32 keyHash, bytes signature, bytes hookData)`
If the length of the data does not match the encoded length the function will revert with `SliceOutOfBounds()`
Also, if the signature is less than 64 bytes, it will revert with `InvalidSignatureLength()`


```solidity
function decodeWithKeyHashAndHookData(bytes calldata data)
    internal
    pure
    returns (bytes32 keyHash, bytes calldata signature, bytes calldata hookData);
```

### decodeAsTypedDataSig

Decode the signature, appSeparator, contentsHash, and contentsDescr from the calldata
the return values MUST be checked for length before use

The calldata is expected to be encoded as `abi.encode(bytes signature, bytes32 appSeparator, bytes32 contentsHash, string contentsDescr)`
there may be an uint16 contentsLength at the end of the calldata, but this is not used
This function should NOT revert, and just returns empty values if the bytes length are incorrect.


```solidity
function decodeAsTypedDataSig(bytes calldata data)
    internal
    pure
    returns (bytes calldata signature, bytes32 appSeparator, bytes32 contentsHash, string calldata contentsDescr);
```

