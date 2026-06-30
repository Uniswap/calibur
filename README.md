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
| Mainnet | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |
| Unichain | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |
| Base | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |
| Optimism | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |
| BNB | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |
| Arbitrum One | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |
| Unichain Sepolia | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |
| Sepolia | 0x00000cAbFc76478C1537dd418aB00967cBbE4AE6 | b0c563e6dfbd4ecacde36b37775bf66c5db6612e | v1.1.0 |

## Audits
- [OpenZeppelin Audit 05/2025](audits/OpenZeppelin_audit.pdf)
- [Cantina Audit 04/2025](audits/Cantina_audit.pdf)

## License
MIT

## Disclaimer
There are a few example hooks referenced in the repo. Be aware that these example hooks are not production code and may contain bugs. We do not recommend you to deploy these hooks or use them as reference implementations for productionized code. They are proof of concepts.
