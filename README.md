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
| Mainnet | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Unichain | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Base | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Optimism | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| BNB | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Arbitrum One | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Unichain Sepolia | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |
| Sepolia | 0x000000009B1D0aF20D8C6d0A44e162d11F9b8f00 | 35d80918e120d177a49d3d90bcd4dd011caedd32 | v1.0.0 |

## Audits
- [OpenZeppelin Audit 05/2025](audits/OpenZeppelin_audit.pdf)
- [Cantina Audit 04/2025](audits/Cantina_audit.pdf)

## License
MIT

## Disclaimer
There are a few example hooks referenced in the repo. Be aware that these example hooks are not production code and may contain bugs. We do not recommend you to deploy these hooks or use them as reference implementations for productionized code. They are proof of concepts.
