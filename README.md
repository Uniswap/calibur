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

| Network | Address | Commit Hash | Version |
|---------|---------|------------|---------|
| Mainnet | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Unichain | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Base | 0x000000005c84F8Fd50b21CAC312528A64437030e | d7d   249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Optimism | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| BNB | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Arbitrum One | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Unichain Sepolia | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |
| Sepolia | 0x000000005c84F8Fd50b21CAC312528A64437030e | 249cac5e880831d7b2de4111a5920dbf0d242846 | v1.1.0 |

## Audits
- [OpenZeppelin Audit 05/2025](audits/OpenZeppelin_audit.pdf)
- [Cantina Audit 04/2025](audits/Cantina_audit.pdf)

## License
MIT

## Disclaimer
There are a few example hooks referenced in the repo. Be aware that these example hooks are not production code and may contain bugs. We do not recommend you to deploy these hooks or use them as reference implementations for productionized code. They are proof of concepts.
