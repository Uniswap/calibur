# KeyManagement
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/KeyManagement.sol)

**Inherits:**
[IKeyManagement](/src/interfaces/IKeyManagement.sol/interface.IKeyManagement.md), [BaseAuthorization](/src/BaseAuthorization.sol/contract.BaseAuthorization.md)

A base contract for managing keys


## State Variables
### keyHashes

```solidity
EnumerableSetLib.Bytes32Set public keyHashes
```


### keyStorage

```solidity
mapping(bytes32 keyHash => bytes encodedKey) private keyStorage
```


### keySettings

```solidity
mapping(bytes32 keyHash => Settings settings) private keySettings
```


## Functions
### register

Registers the `key`.


```solidity
function register(Key memory key) external onlyThis;
```

### update

Updates the `keyHash` with the `keySettings`.


```solidity
function update(bytes32 keyHash, Settings settings) external onlyThis;
```

### revoke

Revokes the key with the `keyHash`.


```solidity
function revoke(bytes32 keyHash) external onlyThis;
```

### keyCount

Returns the number of registered keys.


```solidity
function keyCount() external view returns (uint256);
```

### keyAt

Returns the key at the `i`-th position in the key list.


```solidity
function keyAt(uint256 i) external view returns (Key memory);
```

### getKey

Returns the key corresponding to the `keyHash`. Reverts if the key does not exist.


```solidity
function getKey(bytes32 keyHash) public view returns (Key memory);
```

### getKeySettings

Returns the settings for the `keyHash`.


```solidity
function getKeySettings(bytes32 keyHash) public view returns (Settings);
```

### isRegistered

Returns whether the key is actively registered on the contract.


```solidity
function isRegistered(bytes32 keyHash) public view returns (bool);
```

### _checkCanRegister

Hook for additional validation before a key is registered

Defaults to a no-op; overridden by implementations that reserve certain keys


```solidity
function _checkCanRegister(Key memory key) internal view virtual;
```

### _checkExpiry

Reverts if the key settings are expired


```solidity
function _checkExpiry(Settings settings) internal view;
```

### _isOwnerOrValidKey

Check if the keyHash is the root key or a registered, unexpired key


```solidity
function _isOwnerOrValidKey(bytes32 keyHash) internal view returns (bool);
```

