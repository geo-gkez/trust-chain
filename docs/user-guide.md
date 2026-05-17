# TrustChain User Guide

This guide explains how to use the TrustChain DApp once it is running. It covers connecting your wallet, the actions available to each role, and how to read the batch timeline.

For setup instructions see [deployment.md](deployment.md).

---

## Prerequisites

Before opening the DApp:

1. **MetaMask** installed in your browser
2. **Anvil** running locally (`anvil` in a terminal)
3. **Contract deployed** (`forge script script/Deploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545`)
4. **Dev server running** (`cd ui && npm run dev`)
5. **Your wallet imported** — use one of Anvil's pre-funded accounts (see [Importing Demo Accounts](#importing-demo-accounts))

---

## Connecting Your Wallet

1. Open [http://localhost:5173](http://localhost:5173)
2. Click **Connect Wallet** in the top navigation bar
3. MetaMask will prompt you to add the Anvil network if it doesn't exist yet — approve it

**Anvil network details** (added automatically on first connect):

| Field | Value |
|-------|-------|
| Network name | Anvil Local |
| RPC URL | http://127.0.0.1:8545 |
| Chain ID | 31337 |
| Currency symbol | ETH |

Once connected, the navbar shows your short address and your **role badge** (e.g., `PRODUCER`, `AUDITOR`). If you see no badge, your address is not registered in the contract — switch to a demo account or ask the Admin to register you.

---

## Importing Demo Accounts

The deploy script registers five demo users mapped to Anvil's well-known accounts. Import them into MetaMask using the private keys below.

> These keys are public Anvil defaults. Never use them on mainnet or with real funds.

| Role | Address | Private Key |
|------|---------|-------------|
| Admin (deployer) | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` | `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80` |
| Producer | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` | `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d` |
| Transporter | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` | `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a` |
| Warehouse | `0x90F79bf6EB2c4f870365E785982E1f101E93b906` | `0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6` |
| Distributor | `0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65` | `0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a` |
| Auditor | `0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc` | `0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba` |

---

## Role Workflows

Each role sees a different dashboard when they connect. Below is a step-by-step guide for each.

---

### Admin

The Admin is the contract deployer (Anvil account 0). The admin dashboard shows user management tools.

**Register a new user:**
1. Open **Dashboard**
2. In the **Admin Panel**, enter the Ethereum address, a name, and select a role
3. Click **Register User** — the transaction is sent and confirmed on-chain
4. The user can now connect with that address and their role badge will appear

**Activate / Deactivate a user:**
1. Enter the user's address in the activate or deactivate field
2. Deactivated users cannot perform any role actions until reactivated

**Add product types or units:**
- Use the product type form to register new categories (e.g., "DAIRY", "FROZEN")
- Use the unit form to register new measurement units (e.g., "BOTTLE", "CRATE")

---

### Producer

The Producer creates new batches and hands them off to the first warehouse.

**Create a batch:**
1. Open **Dashboard**
2. In the **Create Batch** form, fill in:
   - **Serial Number** — unique identifier (e.g., `OLIVE-GR-002`)
   - **Product Type** — select from the registered types
   - **Category** — PERISHABLE, NON_PERISHABLE, REFRIGERATED, FRAGILE, or HAZARDOUS
   - **Unit** — measurement unit (KG, L, PCS, etc.)
   - **Quantity** — numeric amount
   - **Origin** — location code (e.g., `GR-PEL`)
   - **Expiry Date** — optional; leave blank for non-perishable goods
3. Click **Create Batch** — the batch is created with status `PRODUCED` and you are the `currentHolder`

**Transfer custody to a warehouse:**
1. In your batch list, find the batch and click **Transfer Custody**
2. Enter the warehouse's Ethereum address
3. Confirm — custody transfers and the batch is ready for the warehouse to receive

---

### Transporter

The Transporter picks up batches from warehouses and ships them to the next stop.

**Receive custody (from warehouse):**
1. Open **Dashboard**
2. A batch transferred to your address appears in your queue
3. Click **Receive** (or `receiveBatch`) and enter the pickup location code
4. Batch status moves to `IN_TRANSIT`

**Ship a batch:**
1. Click **Ship** on a batch you hold
2. Enter the vehicle / shipment identifier (e.g., `TRUCK-001`)
3. Confirm — status stays `IN_TRANSIT` with updated location metadata

**Transfer custody to next stop:**
1. Click **Transfer Custody** and enter the destination warehouse or distributor address
2. The recipient must then call `receiveBatch` to confirm

---

### Warehouse

The Warehouse receives batches, stores them, and forwards them to the next leg.

**Receive a batch:**
1. Open **Dashboard** — batches transferred to your address are listed
2. Click **Receive** and enter the warehouse location code (e.g., `WH-ATHENS`)
3. Batch status moves to `STORED`

**Forward to transporter or distributor:**
1. Click **Transfer Custody** and enter the next party's address
2. The transporter or distributor must then receive it

---

### Distributor

The Distributor marks the final delivery of a batch or triggers a recall.

**Distribute a batch:**
1. Open **Dashboard** — accepted batches you hold are listed
2. Click **Distribute** and enter the distribution point (e.g., `DIST-PIR`)
3. Batch status moves to `DISTRIBUTED`

---

### Auditor

The Auditor has read-only access to all batches and can certify or recall them.

**View any batch:**
- Open **Search**, enter a serial number (e.g., `OLIVE-GR-001`), and click Search
- The full batch card shows status, holder, origin, expiry, and certification

**Certify a batch:**
1. In the batch card, click **Certify**
2. The batch is marked certified on-chain — this is a one-way action

**Recall a batch:**
1. Click **Recall** and enter the current location
2. Status moves to `RECALLED` — the batch can no longer be distributed
3. Transfer custody to a warehouse for quarantine storage, then dispose

---

## Searching Batches

The **Search** view (available to all connected users) lets you look up any batch by serial number.

1. Click **Search** in the navbar
2. Enter the exact serial number (case-sensitive, e.g., `PHARMA-GR-001`)
3. The **BatchCard** shows:
   - Current status and holder
   - Product type, category, origin, quantity, unit
   - Expiry date (if set)
   - Certification status
4. Click **View Timeline** to see the full custody history

**Pre-seeded batch serial numbers to try:**

| Serial | Type | Final Status |
|--------|------|-------------|
| `OLIVE-GR-001` | Food | DISTRIBUTED + certified |
| `PHARMA-GR-001` | Pharma | DISPOSED (recalled) |
| `WINE-GR-001` | Food | STORED |
| `HONEY-GR-001` | Food | STORED |
| `VACCINE-GR-001` | Pharma | STORED |
| `AGRI-GR-001` | Agriculture | IN_TRANSIT |
| `STEEL-GR-001` | Industrial | DISTRIBUTED + certified |
| `ELEC-GR-001` | Electronics | PRODUCED |
| `TEXT-GR-001` | Textile | PRODUCED |
| `CHEM-GR-001` | Chemical | PRODUCED |

---

## Reading the Batch Timeline

The **BatchDetail** view reconstructs the full custody history of a batch from on-chain events.

Each row in the timeline represents one `BatchTransitioned` or `BatchCreated` event:

| Column | Meaning |
|--------|---------|
| Status | The status the batch moved TO at this step |
| Location | Location code provided during the transition |
| Holder | Address that held the batch at this step |
| Timestamp | Block timestamp when the event was emitted |

Because Ethereum events are immutable, this timeline is a tamper-proof audit trail — no party can alter a past entry.

---

## Common Error Messages

| Error | Meaning |
|-------|---------|
| `You do not have permission for this action.` | Your role cannot perform this operation |
| `You are not the current holder of this batch.` | Another address currently holds custody — wait for it to be transferred to you |
| `This status change is not allowed.` | The state machine forbids this transition (e.g., skipping a step) |
| `This batch has expired and cannot move forward.` | The expiry date has passed; only recalls and disposals are allowed |
| `A batch with this serial number already exists.` | Choose a unique serial number |
| `A recalled batch cannot be distributed.` | Recalled batches must go through disposal |
| `MetaMask not found.` | Install the MetaMask browser extension |
