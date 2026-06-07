# TrustChain — Supply Chain Tracking on Ethereum

![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636?logo=solidity&logoColor=white)
![Foundry](https://img.shields.io/badge/Foundry-latest-orange?logo=ethereum)
![Vue](https://img.shields.io/badge/Vue-3.5-4FC08D?logo=vue.js&logoColor=white)
![Vuetify](https://img.shields.io/badge/Vuetify-4.0-1867C0?logo=vuetify&logoColor=white)
![ethers.js](https://img.shields.io/badge/ethers.js-v6-3C3C3D)
![Tests](https://img.shields.io/badge/tests-122%20passing-brightgreen)
![License](https://img.shields.io/badge/License-MIT-yellow)

TrustChain is a blockchain-based supply chain tracking system built on Ethereum. It records every step a product batch takes — from production through storage, transport, and distribution to the end consumer — in an immutable on-chain audit trail.

The system uses a Solidity smart contract as the single source of truth. Every custody transfer, status change, and certification is emitted as an event, making the full history of any batch provable and tamper-proof. A Vue 3 web application provides a role-aware interface so each participant in the chain sees only the actions relevant to their role.

---

## Architecture

```
┌─────────────────────────────────────────┐
│       Vue 3 + Vuetify 4  (ui/)          │
│  Views: Home · Dashboard · Search ·     │
│         BatchDetail                     │
└───────┬─────────────────────────┬───────┘
        │ writes (ethers.js v6)   │ reads (GraphQL)
        │ ABI from Foundry output │ lists · history
┌───────▼──────────────┐   ┌──────▼───────────────────┐
│ MetaMask (signer)    │   │ Goldsky subgraph         │
└───────┬──────────────┘   │ (indexes contract events)│
        │ JSON-RPC         └──────▲───────────────────┘
        │                         │ indexes
┌───────▼─────────────────────────┴────────┐
│  Sepolia testnet  (or local Anvil)        │
└──────────────────┬────────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│  TrustChain.sol  (contracts/src/)        │
│  DataTypes.sol · ITrustChain.sol         │
│  Foundry · Solidity 0.8.28              │
└─────────────────────────────────────────┘
```

The frontend **writes** through MetaMask/ethers directly to the contract, but **reads**
batch lists and history from a [Goldsky](https://goldsky.com/) subgraph that indexes the
contract's events — keeping list/timeline queries fast and off the RPC. See
[docs/deployment.md](docs/deployment.md) for deploying the contract and its subgraph.

---

## Roles

| Role | Capabilities |
|------|-------------|
| **Admin** | Register and activate/deactivate users; add product types and units |
| **Producer** | Create new batches; transfer initial custody |
| **Transporter** | Receive custody and ship batches between locations |
| **Warehouse** | Receive, store, and forward batches |
| **Distributor** | Receive and distribute batches to end points; trigger recalls |
| **Auditor** | Read-only access to all data; certify batches; initiate recalls |

---

## Quick Start

**Dev Container (VS Code + Docker):** After cloning, open the repo in VS Code and select **Reopen in Container** — Foundry, Node.js, Slither, and solhint install automatically inside the container. Ports `8545` and `5173` are forwarded to your host, so MetaMask connects to `localhost` as normal. Then follow steps 2–5 below.

**Without Dev Container:** Install [Foundry](https://book.getfoundry.sh/getting-started/installation) and Node.js 18+ on your machine, then follow all steps below.

> MetaMask browser extension is required in both cases.

```bash
# 1. Clone and enter the repo
git clone <repo-url>
cd trust-chain

# 2. Compile the smart contract
cd contracts && forge build

# 3. Start a local Anvil blockchain (keep this terminal open)
anvil

# 4. Deploy the contract with demo data (new terminal, still in contracts/)
forge script script/Deploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545

# 5. Start the UI — contract address is already set in .env.example
cd ../ui
cp .env.example .env
npm install && npm run dev
```

Open [http://localhost:5173](http://localhost:5173) and connect MetaMask to the Anvil network (Chain ID `31337`, RPC `http://127.0.0.1:8545`).

> The contract address (`0x5FbDB2315678afecb367f032d93F642f64180aa3`) is deterministic — deploying from Anvil account 0 at nonce 0 always produces the same address, so no manual copy-paste is needed.

See [docs/deployment.md](docs/deployment.md) for full instructions including testnet deployment.

---

## Demo Data

The deploy script seeds the contract with:

- **5 users** — one per non-admin role (Producer, Transporter, Warehouse, Distributor, Auditor), mapped to Anvil's well-known accounts 1–5
- **10 batches** — covering food, pharma, agriculture, industrial, electronics, textile, and chemical product types
- **2 complete routes:**
  - **Route 1 — Olive Oil** (`OLIVE-GR-001`): full forward chain from production through two warehouse stops to distribution, then auditor-certified
  - **Route 2 — Pharma Recall** (`PHARMA-GR-001`): forward chain followed by contamination recall, quarantine storage, and disposal

---

## Test Suite

```bash
cd contracts
forge test        # run all 106 tests
forge test -vv    # verbose output with logs
forge coverage    # coverage report
```

| Suite | Count | What it covers |
|-------|-------|----------------|
| Unit | 84 | Happy paths, error cases, access control for every function |
| Fuzz | 3 | Randomised inputs over serial numbers, expiry dates, quantities |
| Invariant | 3 | Immutable properties across 128 000 random call sequences |
| E2E | 2 | Full forward chain + recall/reverse logistics workflows |
| **Total** | **106** | |

---

## Security Audit

The contract was audited with two open-source tools:

- **Slither 0.11.5** — 0 high, 0 medium findings. 4 low/informational items, all confirmed false positives.
- **Solhint 6.2.1** — 0 errors. 139 warnings, all non-critical (missing NatSpec tags and gas micro-optimisations).

Security properties verified: no reentrancy (no external calls or ETH transfers), no integer overflow (Solidity 0.8 built-in), role-based access control on every state-changing function, chain-of-custody enforcement via `currentHolder`, expiry enforcement, one-way recall latch.

See [docs/security-audit.md](docs/security-audit.md) for full analysis.

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/user-guide.md](docs/user-guide.md) | How to use the DApp — role-by-role walkthrough |
| [docs/deployment.md](docs/deployment.md) | Deploy locally (Anvil) or to Sepolia testnet |
| [docs/design-spec.md](docs/design-spec.md) | Full system architecture and design decisions |
| [docs/security-audit.md](docs/security-audit.md) | Slither + Solhint findings and analysis |
| [contracts/README.md](contracts/README.md) | Foundry commands — build, test, deploy, audit |
| [ui/README.md](ui/README.md) | Frontend install, structure, and configuration |

---

## License

MIT
