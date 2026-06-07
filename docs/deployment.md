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

On Sepolia the UI does not read events directly from the chain — it reads through a
**Goldsky subgraph**. A Sepolia deployment is therefore three artifacts: the contract,
the subgraph that indexes it, and the frontend configured to point at both.

### 1. Create a contracts/.env file

```bash
# contracts/.env
PRIVATE_KEY=0x<your-wallet-private-key>
SEPOLIA_RPC=https://eth-sepolia.g.alchemy.com/v2/<your-api-key>
ETHERSCAN_API_KEY=<your-etherscan-key>   # used by --verify
```

> Never commit this file. It is already in `.gitignore`.

### 2. Deploy the contract

Use `DeploySepoliaMinimal.s.sol` (not `Deploy.s.sol`). It deploys a fresh contract,
makes the deployer the Admin, and seeds the product-type / unit registries — but
registers **no** demo users (those are created through the UI afterwards). `Deploy.s.sol`
is for local Anvil only; it registers Anvil's hardcoded demo accounts, which do not
exist on Sepolia.

```bash
cd contracts
source .env
forge script script/DeploySepoliaMinimal.s.sol \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast --verify -vvvv
```

Note the printed **contract address** and the **deployment block** (visible on
Etherscan) — both are needed for the subgraph. `--verify` publishes the source to
Etherscan; drop it if you do not need verification.

### 3. Deploy the Goldsky subgraph

The frontend's reads (`fetchMyBatches`, `fetchPendingCustody`, `fetchBatchTimeline`, …)
query a subgraph, so it must be indexing the contract from step 2 before the UI will
show anything. Create a no-code **Instant Subgraph** in the Goldsky dashboard:

| Field | Value |
|-------|-------|
| Network | Ethereum Sepolia |
| Contract address | the address from step 2 |
| Start block | the deployment block from step 2 |
| ABI | auto-fetched from the verified contract (or upload `ui/src/abi/TrustChain.json`) |
| Name / version | e.g. `trustchain` / `2.0.0` |

Because the subgraph is generated from the ABI, every event — including
`CustodyProposed` / `CustodyCancelled` / `CustodyDeclined` — is indexed automatically.
When indexing completes, Goldsky gives you a **query URL** ending in `/gn`; that is your
`VITE_SUBGRAPH_URL`. Re-creating the subgraph after a new contract deploy means bumping
the version (e.g. `2.0.0` → `2.1.0`) and updating the URL.

### 4. Configure the frontend for Sepolia

```bash
# ui/.env
VITE_CONTRACT_ADDRESS=0x<deployed-address>
VITE_SUBGRAPH_URL=https://api.goldsky.com/api/public/<project>/subgraphs/<name>/<version>/gn
VITE_CHAIN_ID=0xaa36a7
VITE_CHAIN_NAME=Sepolia
VITE_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<your-api-key>
```

> Hosting on Vercel? `ui/.env` is gitignored and not used by the build — set the same
> `VITE_*` variables in the Vercel project's Environment Variables, then redeploy.

---

## Environment Variables Reference

| Variable | File | Default | Description |
|----------|------|---------|-------------|
| `PRIVATE_KEY` | `contracts/.env` | — | Deployer private key (testnet only) |
| `SEPOLIA_RPC` | `contracts/.env` | — | Sepolia JSON-RPC endpoint |
| `ETHERSCAN_API_KEY` | `contracts/.env` | — | Etherscan key for `--verify` |
| `VITE_CONTRACT_ADDRESS` | `ui/.env` | **required** | Deployed TrustChain contract address |
| `VITE_SUBGRAPH_URL` | `ui/.env` | **required** | Goldsky subgraph query endpoint (UI reads) |
| `VITE_CHAIN_ID` | `ui/.env` | `0x7a69` (31337) | Chain ID in hex |
| `VITE_CHAIN_NAME` | `ui/.env` | `Anvil Local` | Network display name in MetaMask |
| `VITE_RPC_URL` | `ui/.env` | `http://127.0.0.1:8545` | JSON-RPC endpoint for MetaMask |

`VITE_CONTRACT_ADDRESS` and `VITE_SUBGRAPH_URL` are required; the other `VITE_*`
variables fall back to Anvil defaults if omitted.
