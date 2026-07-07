# KeyLib
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/KeyLib.sol)


## State Variables
### ROOT_KEY_HASH
The sentinel hash value used to represent the root key


```solidity
bytes32 public constant ROOT_KEY_HASH = bytes32(0)
```


## Functions
### hash

Hashes a key

uses the key type and the public key to produce a hash


```solidity
function hash(Key memory key) internal pure returns (bytes32);
```

### isValidPublicKey

Returns whether the key's publicKey is encoded in its expected, minimal form

Secp256k1 must be abi.encode(address) (32 bytes); P256 and WebAuthnP256 must be
abi.encode(uint256 x, uint256 y) (64 bytes).


```solidity
function isValidPublicKey(Key memory key) internal pure returns (bool);
```

### isRootKey

Returns whether the keyHash is the root key hash


```solidity
function isRootKey(bytes32 keyHash) internal pure returns (bool);
```

### isRootKey

Returns whether the key is the root key


```solidity
function isRootKey(Key memory key) internal view returns (bool);
```

### toRootKey

A helper function to get the root key object.


```solidity
function toRootKey() internal view returns (Key memory);
```

### toKeyHash

Turns a calling address into a key hash.

This key must be a SECP256K1 key since it is calling the contract.


```solidity
function toKeyHash(address caller) internal view returns (bytes32);
```

### verify

Verifies a signature from `key` over a `_hash`

Signatures from P256 are expected to be over the `sha256` hash of `_hash`


```solidity
function verify(Key memory key, bytes32 _hash, bytes calldata signature) internal view returns (bool isValid);
```

