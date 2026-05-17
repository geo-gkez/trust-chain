# TrustChain Frontend

Vue 3 + Vuetify 4 web interface for the TrustChain supply chain smart contract.

For full project documentation see the [root README](../README.md). For deployment instructions see [docs/deployment.md](../docs/deployment.md).

---

## Stack

| Technology | Version | Purpose |
|-----------|---------|---------|
| Vue 3 | 3.5 | UI framework (Composition API, `<script setup>`) |
| Vite | 8 | Build tool and dev server |
| Vuetify | 4.0 | Material Design 3 component library |
| Pinia | 3.0 | State management (wallet, toast) |
| Vue Router | 5.0 | Client-side routing |
| ethers.js | v6 | Ethereum provider and contract interactions |
| @mdi/font | 7.4 | Material Design Icons |

---

## Project Structure

```
src/
├── App.vue                  # Root component — navbar, wallet banner, router-view
├── main.js                  # Entry point — Vue app init, Vuetify, Pinia, Router
│
├── views/
│   ├── HomeView.vue         # Landing page — connect wallet, role display
│   ├── DashboardView.vue    # Role-aware dashboard (different UI per role)
│   ├── BatchDetailView.vue  # Full batch data + custody timeline
│   └── SearchView.vue       # Search by serial number
│
├── components/
│   ├── common/
│   │   ├── WalletConnect.vue  # Connect / disconnect button
│   │   └── RoleBadge.vue      # Role chip displayed in navbar
│   ├── batch/
│   │   ├── BatchCard.vue      # Summary card for a single batch
│   │   ├── BatchForm.vue      # Create-batch form (Producer only)
│   │   ├── BatchGrid.vue      # Grid of BatchCards
│   │   ├── BatchTimeline.vue  # Custody history reconstructed from events
│   │   ├── CustodyForm.vue    # Transfer-custody form
│   │   └── TransitionForm.vue # Lifecycle action form (receive, ship, distribute…)
│   └── admin/
│       └── UserForm.vue       # Register-user form (Admin only)
│
├── composables/
│   ├── useUserRole.js    # Fetch and decode the connected wallet's role
│   ├── useBatches.js     # All batch operations (create, receive, ship, distribute, recall…)
│   └── useAdmin.js       # User registration, product type and unit management
│
├── stores/
│   ├── wallet.js         # MetaMask connection, provider, signer, contract instance
│   └── toast.js          # Global toast notification state
│
├── router/
│   └── index.js          # 4 routes + navigation guard (redirects unregistered users)
│
├── plugins/
│   └── vuetify.js        # Vuetify theme configuration
│
└── utils/
    └── contractErrors.js # Parse and humanise Solidity custom errors from MetaMask
```

---

## Install and Run

```bash
# Install dependencies
npm install

# Start the dev server (http://localhost:5173)
npm run dev
```

> `forge build` must have been run first (in `contracts/`) so the ABI file exists at `contracts/out/TrustChain.sol/TrustChain.json`. Vite reads the ABI directly from the Foundry build output.

---

## Build for Production

```bash
npm run build    # outputs to dist/
npm run preview  # serve the production build locally
```

---

## Configuration

Create a `ui/.env` file:

```env
VITE_CONTRACT_ADDRESS=0x<deployed-contract-address>

# Optional — defaults to Anvil local settings
VITE_CHAIN_ID=0x7a69          # 31337 for Anvil, 0xaa36a7 for Sepolia
VITE_CHAIN_NAME=Anvil Local
VITE_RPC_URL=http://127.0.0.1:8545
```

`VITE_CONTRACT_ADDRESS` is the only required variable. The others fall back to Anvil defaults if omitted.

The contract address is printed at the end of `forge script script/Deploy.s.sol --broadcast`.

---

## MetaMask Setup for Anvil

MetaMask will be prompted to add the Anvil network automatically on first wallet connect. If you need to add it manually:

| Field | Value |
|-------|-------|
| Network name | Anvil Local |
| RPC URL | http://127.0.0.1:8545 |
| Chain ID | 31337 |
| Currency symbol | ETH |

See [docs/user-guide.md](../docs/user-guide.md#importing-demo-accounts) for the pre-funded demo account private keys.
