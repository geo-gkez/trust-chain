# Deployment Guide

This guide covers deploying TrustChain to a local Anvil node (development) and to the Sepolia testnet (staging/demo).

---

## Dev Container (VS Code)

If you have [VS Code](https://code.visualstudio.com/) and [Docker](https://www.docker.com/), this is the fastest path — no local tool installation required.

1. Open the repository folder in VS Code.
2. When prompted, click **Reopen in Container** (or open the command palette and run `Dev Containers: Reopen in Container`).
3. Wait for the container to build — it installs Foundry, Node.js 24, Slither, and solhint automatically.

Ports `8545` (Anvil) and `5173` (Vite) are forwarded to your host, so MetaMask connects to `http://127.0.0.1:8545` just as in a local setup.

Once the container is ready, skip the Prerequisites section below and continue from [Local Development (Anvil)](#local-development-anvil).

> **MetaMask note:** MetaMask runs in your host browser and connects via the forwarded port — no special configuration needed inside the container.

---

## Prerequisites

### Foundry

Install Foundry (includes `forge`, `cast`, `anvil`):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify:

```bash
forge --version
anvil --version
```

### Node.js

Node.js 18 or later is required for the frontend. We recommend Node.js 24 LTS.

---

## Local Development (Anvil)

### 1. Compile the contract

```bash
cd contracts
forge build
```

The compiled ABI and bytecode are written to `contracts/out/`. The frontend reads the ABI directly from this directory, so `forge build` must run before `npm run dev`.

### 2. Start Anvil

Open a dedicated terminal and run:

```bash
anvil
```

Anvil starts at `http://127.0.0.1:8545` with Chain ID `31337` and prints 10 pre-funded accounts (10 000 ETH each). The first six accounts (0–5) are used by the deploy script.

Keep this terminal open — Anvil must stay running while you use the DApp.

### 3. Deploy the contract

In a second terminal (still in `contracts/`):

```bash
forge script script/Deploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545
```

No `--private-key` flag is needed — the script uses Anvil's well-known private keys internally.

The script:
1. Deploys `TrustChain.sol`
2. Registers 5 users (Producer, Transporter, Warehouse, Distributor, Auditor)
3. Creates 10 batches across 7 product categories
4. Executes 2 complete routes (forward chain + recall/disposal)

At the end of the output you will see:

```
=== TrustChain deployed at: 0x5FbDB2315678afecb367f032d93F642f64180aa3 ===
```

### 4. Configure the frontend

```bash
cd ../ui
cp .env.example .env
```

The `.env.example` already contains the correct address (`0x5FbDB2315678afecb367f032d93F642f64180aa3`). This is deterministic — deploying from Anvil account 0 at nonce 0 always produces the same address on a fresh Anvil instance.

### 5. Start the dev server

```bash
npm install   # only needed the first time
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).

### 6. Connect MetaMask

MetaMask will automatically be prompted to add the Anvil network on first connect. If it doesn't, add it manually:

| Field | Value |
|-------|-------|
| Network name | Anvil Local |
| RPC URL | http://127.0.0.1:8545 |
| Chain ID | 31337 |
| Currency symbol | ETH |

Import the demo accounts from [docs/user-guide.md](user-guide.md#importing-demo-accounts) to use each role.

---

## What the Deploy Script Creates

| Batch | Product Type | Category | Final Status |
|-------|-------------|----------|-------------|
| `OLIVE-GR-001` | Food | Perishable | DISTRIBUTED + certified |
| `PHARMA-GR-001` | Pharma | Refrigerated | DISPOSED (recalled) |
| `WINE-GR-001` | Food | Non-perishable | STORED |
| `HONEY-GR-001` | Food | Non-perishable | STORED |
| `VACCINE-GR-001` | Pharma | Refrigerated | STORED |
| `AGRI-GR-001` | Agriculture | Perishable | IN_TRANSIT |
| `STEEL-GR-001` | Industrial | Non-perishable | DISTRIBUTED + certified |
| `ELEC-GR-001` | Electronics | Fragile | PRODUCED |
| `TEXT-GR-001` | Textile | Non-perishable | PRODUCED |
| `CHEM-GR-001` | Chemical | Hazardous | PRODUCED |

**Route 1 — Olive Oil** (`OLIVE-GR-001`):
```
PRODUCED → STORED (WH-KALAMATA) → IN_TRANSIT (TRUCK-001)
         → STORED (WH-ATHENS)   → IN_TRANSIT (TRUCK-002)
         → DISTRIBUTED (DIST-PIR) → certified
```

**Route 2 — Pharma Recall** (`PHARMA-GR-001`):
```
PRODUCED → STORED (WH-ATHENS) → IN_TRANSIT (TRUCK-PHARMA)
         → DISTRIBUTED (DIST-ATH) → RECALLED
         → STORED (WH-QUARANTINE) → DISPOSED
```

---

## Resetting the Local State

Anvil resets every time it restarts. After a restart:

1. Run `forge script script/Deploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545` again
2. Update `ui/.env` with the new contract address
3. Reset the MetaMask account nonces: MetaMask → Settings → Advanced → Clear activity and nonce data

---

## Sepolia Testnet

### Prerequisites

- A funded Sepolia wallet (use a faucet: [sepoliafaucet.com](https://sepoliafaucet.com))
- A Sepolia RPC URL from [Alchemy](https://www.alchemy.com/) or [Infura](https://infura.io/)

### 1. Create a contracts/.env file

```bash
# contracts/.env
PRIVATE_KEY=0x<your-wallet-private-key>
SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/<your-api-key>
```

> Never commit this file. It is already in `.gitignore`.

### 2. Deploy

```bash
cd contracts
forge script script/Deploy.s.sol \
  --broadcast \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

The deployer account becomes the Admin. The demo users registered by the script will use Anvil's hardcoded addresses — on Sepolia you will want to modify `Deploy.s.sol` to register your own addresses.

### 3. Verify on Etherscan (optional)

```bash
forge verify-contract <contract-address> src/TrustChain.sol:TrustChain \
  --chain sepolia \
  --etherscan-api-key <your-etherscan-key>
```

### 4. Configure the frontend for Sepolia

```bash
# ui/.env
VITE_CONTRACT_ADDRESS=0x<deployed-address>
VITE_CHAIN_ID=0xaa36a7
VITE_CHAIN_NAME=Sepolia
VITE_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<your-api-key>
```

---

## Environment Variables Reference

| Variable | File | Default | Description |
|----------|------|---------|-------------|
| `PRIVATE_KEY` | `contracts/.env` | — | Deployer private key (testnet only) |
| `SEPOLIA_RPC` | `contracts/.env` | — | Sepolia JSON-RPC endpoint |
| `VITE_CONTRACT_ADDRESS` | `ui/.env` | **required** | Deployed TrustChain contract address |
| `VITE_CHAIN_ID` | `ui/.env` | `0x7a69` (31337) | Chain ID in hex |
| `VITE_CHAIN_NAME` | `ui/.env` | `Anvil Local` | Network display name in MetaMask |
| `VITE_RPC_URL` | `ui/.env` | `http://127.0.0.1:8545` | JSON-RPC endpoint for MetaMask |

All `VITE_*` variables are optional except `VITE_CONTRACT_ADDRESS`. Omitting the others falls back to Anvil defaults.
