# Calibur
> _a derivation of *Excalibur* and a nod to the mythical sword's reputation as a symbol of rightful authority and exceptional power_

A minimal non-upgradeable implementation contract that can be set on an EIP-7702 delegation transaction.

## Installation
```bash
foundryup --install nightly

cd test/js-scripts && yarn && yarn build

forge test
```

## Deployment Addresses

All deployments listed below are `CaliburEntry` v1.1.0 at `0x000000005c84F8Fd50b21CAC312528A64437030e` (commit `249cac5e880831d7b2de4111a5920dbf0d242846`). It is deployed with CREATE2 through the deterministic deployment proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`), so the address is the same on every chain listed. Every row was checked onchain with `eth_getCode` against the Ethereum mainnet runtime bytecode.

> **Note on EIP-712:** v1.1.0 uses the EIP-712 domain version `"1.0.0"` (see `_domainNameAndVersion()` in `src/EIP712.sol`). Integrators should sign with `name = "Calibur"`, `version = "1.0.0"`. The domain's `salt` field packs the implementation address (`verifyingContract` is the delegated account), so read the domain with `eip712Domain()` rather than hardcoding it.

### What changed in v1.1.0

v1.1.0 removes `multicall(bytes[])` (`IMulticall`) and the transient native allowance functions `approveNativeTransient(address,uint256)`, `transferFromNativeTransient(address,address,uint256)` and `transientNativeAllowance(address)` (with their `ApproveNativeTransient` and `TransferFromNativeTransient` events); `updateSalt(uint96)` becomes `updateSalt()`; and it adds the `ERC20ETH()` getter and the errors `CannotRegisterKey`, `InvalidHook`, `InvalidKey`, `InvalidSettings` and `OnlyAdminCanCallEntryPoint`.

### Deployments

| Network | Chain ID | Address | Commit Hash |
|---------|----------|---------|-------------|
| Mainnet | 1 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Optimism | 10 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| BNB | 56 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Gnosis | 100 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Unichain | 130 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Polygon | 137 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Monad | 143 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| X Layer | 196 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| World Chain | 480 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Robinhood | 4663 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Arc | 5042 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Base | 8453 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Arbitrum One | 42161 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Ink | 57073 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Unichain Sepolia | 1301 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Monad Testnet | 10143 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Robinhood Testnet | 46630 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Base Sepolia | 84532 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |
| Sepolia | 11155111 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 |

### Not deployed

- **Metis (1088):** Metis does not support EIP-7702 or the Cancun opcodes (`TSTORE`, `MCOPY`), so Calibur v1.1.0 is not deployed there.
- **Avalanche C-Chain (43114):** Avalanche C-Chain does not support EIP-7702 yet (ACP-209 is still a proposal), so Calibur v1.1.0 is not deployed there.

## Audits
- [OpenZeppelin Audit 05/2025](audits/OpenZeppelin_audit.pdf)
- [Cantina Audit 04/2025](audits/Cantina_audit.pdf)

## License
MIT

## Disclaimer
There are a few example hooks referenced in the repo. Be aware that these example hooks are not production code and may contain bugs. We do not recommend you to deploy these hooks or use them as reference implementations for productionized code. They are proof of concepts.
