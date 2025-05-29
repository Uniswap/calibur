# IERC1271
[Git Source](https://github.com/Uniswap/minimal-delegation/blob/1457ed9d5e0382ab8547f6bc36a3738475e8b5fe/src/interfaces/IERC1271.sol)


## Functions
### isValidSignature

Validates the `signature` against the given `hash`.

*Supports the following signature workflows:
- 64 or 65-byte ECDSA signatures from address(this)
- Nested typed data signatures as defined by ERC-7739
- Nested personal signatures as defined by ERC-7739*

*A wrappedSignature contains a keyHash, signature, and any optional hook data
`signature` can contain extra fields used for webauthn verification or ERC7739 nested typed data verification*

*An unwrapped signature is only valid for the root key. However, the root key can also sign a 7739 rehashed signature.
It is possible for an unwrapped signature from the root key to be replayed IF the root key is registered on another wallet, not this one, and that wallet
does not enforce defensive rehashing for its keys. If this is a concern, use a 7739 wrapped signature for the root key.*


```solidity
function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|result `0x1626ba7e` if validation succeeded, else `0xffffffff`.|


