# SettingsLib
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/libraries/SettingsLib.sol)

**Title:**
SettingsLib

Key settings are packed into a uint256 where
- the least significant 20 bytes (0-19) specify an address to callout to for extra or overrideable validation.
- bytes 20-24 are used for the expiration timestamp.
- bit 200 specifies whether the key is an admin key.
- bits 201-255 are reserved for future use and must be unset.
bits 201-255 |  bit 200  | 5 bytes      | 20 bytes
RESERVED     |  isAdmin  | expiration   | hook


## State Variables
### MASK_20_BYTES

```solidity
uint160 constant MASK_20_BYTES = uint160(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)
```


### MASK_5_BYTES

```solidity
uint40 constant MASK_5_BYTES = uint40(0xFFFFFFFFFF)
```


### RESERVED_BITS
Mask covering bits 201-255, which sit above the admin flag (bit 200) and are reserved for future use.
The admin flag is a single bit, so a settings word with these bits set is rejected on update.


```solidity
uint256 constant RESERVED_BITS = type(uint256).max << 201
```


### DEFAULT

```solidity
Settings constant DEFAULT = Settings.wrap(0)
```


### ROOT_KEY_SETTINGS

```solidity
Settings constant ROOT_KEY_SETTINGS = Settings.wrap(uint256(1) << 200)
```


## Functions
### isAdmin

Returns whether the key is an admin key


```solidity
function isAdmin(Settings settings) internal pure returns (bool _isAdmin);
```

### expiration

Returns the expiration timestamp in unix time


```solidity
function expiration(Settings settings) internal pure returns (uint40 _expiration);
```

### hook

Returns the hook address of the key


```solidity
function hook(Settings settings) internal pure returns (IHook _hook);
```

### isExpired

A key is expired if its expiration is less than the current block timestamp
Strictly less than is inline with how expiry is handled in the ERC-4337 EntryPoint contract

Keys with expiry of 0 never expire.


```solidity
function isExpired(Settings settings) internal view returns (bool _isExpired, uint40 _expiration);
```

