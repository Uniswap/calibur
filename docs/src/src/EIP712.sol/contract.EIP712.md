# EIP712
[Git Source](https://github.com/Uniswap/calibur/blob/249cac5e880831d7b2de4111a5920dbf0d242846/src/EIP712.sol)

**Inherits:**
[IEIP712](/src/interfaces/IEIP712.sol/interface.IEIP712.md), IERC5267, [BaseAuthorization](/src/BaseAuthorization.sol/contract.BaseAuthorization.md)

**Title:**
EIP712

It is not compatible with use by proxy contracts since the domain name and version are cached on deployment.

This contract does not cache the domain separator and instead calculates it on the fly
since it will change when delegated to or when the salt is updated.


## State Variables
### _DOMAIN_TYPEHASH
`keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)")`.


```solidity
bytes32 internal constant _DOMAIN_TYPEHASH = 0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472
```


### _cachedNameHash
Cached name and version hashes for cheaper runtime gas costs.


```solidity
bytes32 private immutable _cachedNameHash
```


### _cachedVersionHash

```solidity
bytes32 private immutable _cachedVersionHash
```


### _cachedImplementation

```solidity
address private immutable _cachedImplementation
```


### _saltPrefix
Any prefix to be added to the salt. This can be updated by the owner or an admin but it defaults to 0.


```solidity
uint96 private _saltPrefix
```


## Functions
### constructor


```solidity
constructor() ;
```

### eip712Domain

Returns information about the `EIP712Domain` used to create EIP-712 compliant hashes.

Follows ERC-5267 (see https://eips.ethereum.org/EIPS/eip-5267).


```solidity
function eip712Domain()
    public
    view
    virtual
    returns (
        bytes1 fields,
        string memory name,
        string memory version,
        uint256 chainId,
        address verifyingContract,
        bytes32 salt,
        uint256[] memory extensions
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fields`|`bytes1`|The bitmap of used fields.|
|`name`|`string`|The value of the `EIP712Domain.name` field.|
|`version`|`string`|The value of the `EIP712Domain.version` field.|
|`chainId`|`uint256`|The value of the `EIP712Domain.chainId` field.|
|`verifyingContract`|`address`|The value of the `EIP712Domain.verifyingContract` field.|
|`salt`|`bytes32`|The value of the `EIP712Domain.salt` field.|
|`extensions`|`uint256[]`|The list of EIP numbers, that extends EIP-712 with new domain fields.|


### domainBytes

Encode the EIP-5267 domain into bytes

for use in ERC-7739


```solidity
function domainBytes() public view returns (bytes memory);
```

### domainSeparator

Returns the `domainSeparator` used to create EIP-712 compliant hashes.


```solidity
function domainSeparator() public view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The 32 bytes domain separator result.|


### hashTypedData

Public getter for `_hashTypedData()` to produce a EIP-712 hash using this account's domain separator


```solidity
function hashTypedData(bytes32 hash) public view virtual returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`hash`|`bytes32`|The nested typed data. Assumes the hash is the result of applying EIP-712 `hashStruct`.|


### updateSalt

Increment the EIP-712 domain salt prefix, the upper 96 bits of the salt
12 bytes | 20 bytes
prefix   | Implementation address (immutable, set on deployment)

Use this to invalidate existing signatures signed under the old domain separator.


```solidity
function updateSalt() external onlyThis;
```

### _domainNameAndVersion

Returns the domain name and version to use when creating EIP-712 signatures.


```solidity
function _domainNameAndVersion() internal pure returns (string memory name, string memory version);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|   The user readable name of signing domain.|
|`version`|`string`|The current major version of the signing domain.|


