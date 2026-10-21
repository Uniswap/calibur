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

`CaliburEntry` is deployed with CREATE2 through the deterministic deployment proxy (`0x4e59b44847b379578588920cA78FbF26c0B4956C`), so each version has the same address on every chain listed below. Every row was checked onchain with `eth_getCode` against the Ethereum mainnet runtime bytecode.

> **Note on EIP-712:** v1.1.0 still uses the EIP-712 domain version `"1.0.0"` (see `_domainNameAndVersion()` in `src/EIP712.sol`). Integrators should keep signing with `name = "Calibur"`, `version = "1.0.0"` for both v1.0.0 and v1.1.0 delegations. The two versions produce different domain separators through the `salt` field, which packs the implementation address (`verifyingContract` is the delegated account in both). Read the domain with `eip712Domain()` rather than hardcoding it. v1.1.0 also removes `multicall` (`IMulticall`), which v1.0.0 exposed.

### v1.1.0 (latest)

| Network | Chain ID | Address | Commit Hash | Version |
|---------|----------|---------|-------------|---------|
| Mainnet | 1 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Optimism | 10 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| BNB | 56 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Gnosis | 100 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Unichain | 130 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Polygon | 137 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Monad | 143 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| X Layer | 196 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| World Chain | 480 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Robinhood | 4663 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Arc | 5042 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Base | 8453 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Arbitrum One | 42161 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Ink | 57073 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Unichain Sepolia | 1301 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Monad Testnet | 10143 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Robinhood Testnet | 46630 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Base Sepolia | 84532 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Sepolia | 11155111 | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |

### v1.0.0

| Network | Chain ID | Address | Commit Hash | Version |
|---------|----------|---------|-------------|---------|
| Mainnet | 1 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Optimism | 10 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| BNB | 56 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Gnosis | 100 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Unichain | 130 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Polygon | 137 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Monad | 143 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Sonic | 146 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| X Layer | 196 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| World Chain | 480 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Flow EVM | 747 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Metis | 1088 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Sei | 1329 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Story | 1514 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Abstract | 2741 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Tempo | 4217 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| MegaETH | 4326 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Robinhood | 4663 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Mantle | 5000 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Arc | 5042 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Base | 8453 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Plasma | 9745 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Arbitrum One | 42161 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Avalanche C-Chain | 43114 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Ink | 57073 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Linea | 59144 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| BOB | 60808 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Berachain | 80094 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Zora | 7777777 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Unichain Sepolia | 1301 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Base Sepolia | 84532 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Arbitrum Sepolia | 421614 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Sepolia | 11155111 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| OP Sepolia | 11155420 | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |

## Audits
- [OpenZeppelin Audit 05/2025](audits/OpenZeppelin_audit.pdf)
- [Cantina Audit 04/2025](audits/Cantina_audit.pdf)

## License
MIT

## Disclaimer
There are a few example hooks referenced in the repo. Be aware that these example hooks are not production code and may contain bugs. We do not recommend you to deploy these hooks or use them as reference implementations for productionized code. They are proof of concepts.
