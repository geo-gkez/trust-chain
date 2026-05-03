# TrustChain UI — Junior Developer Guide

> Welcome to the TrustChain frontend! This guide explains the project structure, how the main pieces fit together, and the patterns you will see repeated throughout the codebase.

---

## Table of Contents

1. [What is this project?](#1-what-is-this-project)
2. [Tech Stack at a Glance](#2-tech-stack-at-a-glance)
3. [Project Structure](#3-project-structure)
4. [Getting Started Locally](#4-getting-started-locally)
5. [How the App Boots](#5-how-the-app-boots)
6. [Routing](#6-routing)
7. [Global State (Pinia Stores)](#7-global-state-pinia-stores)
8. [Composables — Reusable Logic](#8-composables--reusable-logic)
9. [Components](#9-components)
10. [Views (Pages)](#10-views-pages)
11. [Talking to the Blockchain](#11-talking-to-the-blockchain)
12. [Theming & UI Library](#12-theming--ui-library)
13. [Environment Variables](#13-environment-variables)
14. [Common Patterns You Will See](#14-common-patterns-you-will-see)
15. [Glossary](#15-glossary)

---

## 1. What is this project?

TrustChain is a **supply chain traceability DApp** (Decentralised Application). A DApp is a normal web application that talks to a smart contract deployed on a blockchain instead of (or in addition to) a traditional backend.

Users connect their **MetaMask wallet** to identify themselves. Their Ethereum address acts as their login. Depending on the role assigned to their address in the smart contract, they see different tools: producers create batches, transporters ship them, auditors certify or recall them, etc.

---

## 2. Tech Stack at a Glance

| Tool             | Purpose                                                             |
| ---------------- | ------------------------------------------------------------------- |
| **Vue 3**        | UI framework. We use the Composition API with `<script setup>`.     |
| **Vuetify 4**    | Material Design component library (buttons, cards, forms, etc.).    |
| **Pinia**        | State management — like a global store shared across components.    |
| **Vue Router 4** | Client-side routing (which component to show for each URL).         |
| **Ethers.js v6** | Library for talking to the Ethereum blockchain and smart contracts. |
| **Vite**         | Build tool and dev server. Very fast.                               |

---

## 3. Project Structure

```
ui/
├── index.html              ← Single HTML page that loads the app
├── vite.config.js          ← Build configuration, path aliases
├── package.json            ← Dependencies and npm scripts
├── .env                    ← Your local environment variables (NOT committed)
├── .env.example            ← Template showing which variables are needed
└── src/
    ├── main.js             ← App entry point — creates the Vue app
    ├── App.vue             ← Root component: app bar, drawer, global alerts
    ├── style.css           ← Global CSS overrides
    │
    ├── plugins/
    │   └── vuetify.js      ← Vuetify setup + custom colour theme
    │
    ├── router/
    │   └── index.js        ← All routes + navigation guard
    │
    ├── stores/
    │   ├── wallet.js       ← Wallet connection state (account, contract, etc.)
    │   └── toast.js        ← Global toast/snackbar notifications
    │
    ├── composables/
    │   ├── useUserRole.js  ← Current user's role fetched from the contract
    │   ├── useBatches.js   ← All batch-related contract calls + helpers
    │   └── useAdmin.js     ← Admin-only contract calls (users, registries)
    │
    ├── components/
    │   ├── common/
    │   │   ├── WalletConnect.vue   ← Connect / Disconnect button
    │   │   ├── RoleBadge.vue       ← Coloured chip showing a role name
    │   │   └── AddressChip.vue     ← Short address with tooltip
    │   ├── batch/
    │   │   ├── BatchCard.vue       ← Summary card for a batch
    │   │   ├── BatchForm.vue       ← Form to create a new batch
    │   │   ├── BatchTimeline.vue   ← Chronological event history
    │   │   └── TransitionForm.vue  ← Form to change a batch's status
    │   └── admin/
    │       └── UserForm.vue        ← Form to register a new user
    │
    └── views/
        ├── HomeView.vue        ← Landing page
        ├── DashboardView.vue   ← Role-based action dashboard
        ├── SearchView.vue      ← Search a batch by serial number
        └── BatchDetailView.vue ← Full detail + timeline for one batch
```

**Rule of thumb:**

- **Views** are the pages you navigate to. They assemble composables and components.
- **Components** are reusable building blocks that receive data via props and emit events.
- **Composables** are functions that encapsulate reactive state + logic (especially contract calls).
- **Stores** hold global state that many parts of the app need to read.

---

## 4. Getting Started Locally

### Prerequisites

- Node.js ≥ 18
- MetaMask browser extension
- The Anvil local blockchain running (`anvil` in the contracts folder)
- The TrustChain contract deployed (see `contracts/README.md`)

### Steps

```bash
# 1. Install dependencies
cd ui
npm install

# 2. Set the deployed contract address
cp .env.example .env
# Edit .env and paste the address shown after running the deploy script

# 3. Start the dev server
npm run dev
# Opens at http://localhost:5173
```

### Building for production

```bash
npm run build     # outputs to dist/
npm run preview   # preview the production build locally
```

---

## 5. How the App Boots

`index.html` loads `src/main.js`, which does four things in order:

```js
const app = createApp(App); // 1. Create the Vue application

app.use(createPinia()); // 2. Register Pinia (global stores)
app.use(vuetify); // 3. Register Vuetify (UI components + theme)
app.use(router); // 4. Register Vue Router

app.mount("#app"); // 5. Attach to the <div id="app"> in index.html
```

After this, Vue renders `App.vue` as the root component. `App.vue` contains the persistent shell (app bar, navigation drawer, global alerts) and a `<router-view />` which is replaced by the current page's component.

---

## 6. Routing

**File:** `src/router/index.js`

There are four routes:

| Path             | Name           | View              | Auth? |
| ---------------- | -------------- | ----------------- | ----- |
| `/`              | `home`         | `HomeView`        | No    |
| `/dashboard`     | `dashboard`    | `DashboardView`   | Yes   |
| `/batch/:serial` | `batch-detail` | `BatchDetailView` | Yes   |
| `/search`        | `search`       | `SearchView`      | Yes   |

Routes marked **Auth: Yes** have `meta: { requiresAuth: true }`. The **navigation guard** (`router.beforeEach`) runs before every navigation:

1. If the route does not require auth → allow.
2. If the wallet is not connected → redirect to `/` with `?redirect=...`.
3. If the wallet is connected → call the contract to check if the address is registered and active. If not, redirect to `/` with `?reason=unregistered` or `?reason=inactive`.

### Using `<router-link>` in templates

Vuetify components like `<v-btn>` and `<v-card>` accept a `to` prop that works like `<router-link>`:

```vue
<v-btn to="/dashboard">Go to Dashboard</v-btn>
<BatchCard :link-to="`/batch/${b.serialNumber}`" />
```

### Navigating programmatically

```js
import { useRouter } from "vue-router";
const router = useRouter();
router.push("/dashboard");
router.replace({ query: {} }); // change URL without adding a history entry
```

---

## 7. Global State (Pinia Stores)

Pinia stores are singletons — every component that calls `useWalletStore()` gets the **same** object.

### `wallet.js` — Wallet Store

Holds everything related to the user's connection.

| Property       | Type                      | Description                                           |
| -------------- | ------------------------- | ----------------------------------------------------- |
| `account`      | `string \| null`          | Connected Ethereum address (e.g. `"0xabc...1234"`)    |
| `contract`     | `Contract \| null`        | Ethers.js `Contract` instance (ready to call methods) |
| `provider`     | `BrowserProvider \| null` | Ethers.js provider (used to fetch blocks)             |
| `error`        | `string \| null`          | Last connection error message                         |
| `isConnecting` | `boolean`                 | True while connecting                                 |

**Getters (computed):**

| Getter         | Returns                                           |
| -------------- | ------------------------------------------------- |
| `isConnected`  | `true` when both `account` and `contract` are set |
| `shortAddress` | `"0xabc…1234"` — first 6 + last 4 chars           |

**Actions:**

| Action         | Does                                                                       |
| -------------- | -------------------------------------------------------------------------- |
| `connect()`    | Requests MetaMask accounts, switches to the right chain, builds `Contract` |
| `disconnect()` | Clears all state                                                           |

```js
// How to use it in any component
import { useWalletStore } from "@/stores/wallet";
const wallet = useWalletStore();

// In template
wallet.isConnected; // boolean
wallet.shortAddress; // "0xabc…1234"
wallet.account; // full address

// In script
await wallet.connect();
wallet.disconnect();
```

### `toast.js` — Toast Store

Shows a brief notification at the bottom-right of the screen.

```js
import { useToastStore } from "@/stores/toast";
const toast = useToastStore();

toast.show("Batch created!", "success"); // green
toast.show("Transaction failed", "error"); // red
toast.show("Check your wallet", "warning");
```

The snackbar rendering is in `App.vue` — you just call `toast.show()` from anywhere.

---

## 8. Composables — Reusable Logic

A **composable** is a function whose name starts with `use`. It sets up reactive state and returns it. Think of it as a hook (similar to React hooks if you've seen those).

### `useUserRole.js`

Fetches the current user's role from the smart contract whenever the wallet account changes.

```js
import { useUserRole } from "@/composables/useUserRole";
const { role, roleLabel, isActive, isRegistered, isLoading } = useUserRole();

// roleLabel.value === 'PRODUCER' | 'ADMIN' | 'AUDITOR' | etc.
// role.value       === 0 | 1 | 2 | 3 | 4 | 5  (numeric enum from contract)
// isActive.value   === true/false
```

It also exports:

- `ROLES` — maps numeric role (`0`) to label (`'PRODUCER'`)
- `ROLE_COLORS` — maps role label to a Vuetify colour name

### `useBatches.js`

All batch-related contract interactions.

```js
import { useBatches } from "@/composables/useBatches";
const { loading, error, fetchBatch, createBatch, shipBatch /* ... */ } =
  useBatches();
```

Every method sets `loading.value = true` before the call and `false` after. On error, it sets `error.value` and shows a toast automatically.

It also exports these **pure utility functions** (no reactive state):

| Function                  | Purpose                                               |
| ------------------------- | ----------------------------------------------------- |
| `parseContractError(err)` | Converts an Ethers error into a human-readable string |
| `bytes32ToString(b32)`    | Decodes a bytes32 hex string to a JS string           |
| `stringToBytes32(str)`    | Encodes a JS string to bytes32                        |
| `decodeBatch(raw)`        | Converts a raw contract struct to a plain JS object   |
| `STATUS_LABELS`           | `{ 0: 'PRODUCED', 1: 'STORED', ... }`                 |
| `STATUS_COLORS`           | `{ PRODUCED: 'grey', STORED: 'blue', ... }`           |
| `CATEGORY_LABELS`         | `{ 0: 'PERISHABLE', ... }`                            |

### `useAdmin.js`

Admin and read-helper functions: `registerUser`, `deactivateUser`, `activateUser`, `fetchAllUsers`, `getProductTypes`, `getUnits`, `addProductType`, `addUnit`, `getUser`.

Same loading/error/toast pattern as `useBatches`.

---

## 9. Components

### Common Components

#### `WalletConnect.vue`

A single button that toggles between connecting and disconnecting.

```vue
<WalletConnect />
<!-- inline button -->
<WalletConnect block />
<!-- full-width button -->
```

Props: `block` (Boolean, default `false`).

#### `RoleBadge.vue`

A coloured chip showing a role name.

```vue
<RoleBadge role="ADMIN" />
<RoleBadge role="PRODUCER" />
```

Props: `role` (String, required) — must be one of `ADMIN`, `PRODUCER`, `TRANSPORTER`, `WAREHOUSE`, `DISTRIBUTOR`, `AUDITOR`.

#### `AddressChip.vue`

Shows a shortened address (`0xabc…1234`) with a tooltip showing the full address on hover.

```vue
<AddressChip address="0xabcdef..." />
```

Props: `address` (String).

---

### Batch Components

#### `BatchCard.vue`

Displays a summary of one batch. Can optionally be a clickable link.

```vue
<BatchCard
  :batch="batchObject"
  :product-types="['Olive Oil', 'Wine']"
  :units="['kg', 'litre']"
  link-to="/batch/OLIVE-GR-001"
/>
```

Props:

- `batch` — decoded batch object from `decodeBatch()`
- `productTypes` — array of product type strings (index = ID)
- `units` — array of unit strings (index = ID)
- `linkTo` — optional route path or object, makes the card clickable

#### `BatchForm.vue`

A form for creating a new batch. Emits `created` when successful.

```vue
<BatchForm @created="onBatchCreated" />
```

Handles its own loading state and validation. Fetches product types and units from the contract on mount.

#### `BatchTimeline.vue`

Fetches and renders the full event history of a batch as a vertical timeline.

```vue
<BatchTimeline serial-number="OLIVE-GR-001" />
```

Props: `serialNumber` (String, required). It fetches the timeline by itself using `useBatches`.

#### `TransitionForm.vue`

A small form for changing a batch's status (ship, receive, distribute, recall, dispose).

```vue
<TransitionForm
  action="shipBatch"
  label="Ship Batch"
  icon="mdi-truck-fast"
  color="blue"
  @done="refresh"
/>
```

Props: `action` (String — must match a method name on the contract), `label`, `icon`, `color`.
Emits: `done` after a successful transaction.

---

### Admin Components

#### `UserForm.vue`

A form for registering a new user on-chain. Emits `registered` when successful.

```vue
<UserForm @registered="onUserRegistered" />
```

---

## 10. Views (Pages)

### `HomeView.vue`

The public landing page. Shows:

- A hero section with a wallet connect button (if not connected) or navigation buttons (if connected).
- Feature cards explaining the system.
- A role overview table.

### `DashboardView.vue`

The main workspace. Uses `v-expansion-panels` to show only the section relevant to the connected user's role. Each panel maps to a role:

- **ADMIN** → Register users, manage users, manage product types and units.
- **PRODUCER** → Create batches, view own batches.
- **WAREHOUSE** → Receive and dispose batches.
- **TRANSPORTER** → Ship batches.
- **DISTRIBUTOR** → Distribute batches.
- **AUDITOR** → Recall and certify batches.

### `SearchView.vue`

A simple search page. Enter a serial number, get a `BatchCard` preview, then navigate to the full detail page.

### `BatchDetailView.vue`

Shows the full details of a single batch (all fields) plus the `BatchTimeline` component. The serial number comes from the URL parameter `route.params.serial`.

---

## 11. Talking to the Blockchain

Understanding this flow is the most important part of working on this project.

```
User action in UI
     │
     ▼
Composable method (e.g. useBatches.createBatch)
     │
     ▼
wallet.contract.<methodName>(...args)   ← Ethers.js call
     │
     ▼
MetaMask pop-up → user confirms
     │
     ▼
tx.wait()   ← waits for the transaction to be mined
     │
     ▼
toast.show('Success!', 'success')
```

### Read calls vs write calls

| Type                   | Gas cost | MetaMask pop-up? | Example                     |
| ---------------------- | -------- | ---------------- | --------------------------- |
| Read (view/pure)       | Free     | No               | `contract.getBatch(serial)` |
| Write (state-changing) | Yes      | Yes              | `contract.createBatch(...)` |

For write calls, always `await tx.wait()` — this waits until the block is mined. Without it, your UI might update before the transaction is confirmed.

### How contracts are loaded

`vite.config.js` sets an alias:

```js
'@trustchain-abi': path.resolve(__dirname, '../contracts/out/TrustChain.sol/TrustChain.json')
```

This means anywhere in the code you can do:

```js
import TrustChainArtifact from "@trustchain-abi";
// TrustChainArtifact.abi is the contract ABI (method signatures)
```

The contract object is created in `wallet.js`:

```js
new Contract(CONTRACT_ADDRESS, TrustChainArtifact.abi, signer);
```

After this, you call methods like: `contract.getBatch(serial)`, `contract.createBatch(...)`, etc.

### `bytes32` — a common gotcha

Solidity's `bytes32` type holds a fixed-length 32-byte value. When you pass a string from JavaScript, you must encode it first:

```js
import { stringToBytes32, bytes32ToString } from '@/composables/useBatches'

// Sending to contract:
contract.createBatch(stringToBytes32('OLIVE-GR-001'), ...)

// Reading from contract:
const readable = bytes32ToString(raw.serialNumber)
```

Strings longer than 31 characters will throw. The form validation in `BatchForm.vue` and `UserForm.vue` enforces this with a `rules.bytes32` rule.

---

## 12. Theming & UI Library

The UI uses **Vuetify 4**, configured in `src/plugins/vuetify.js` with a custom dark theme called `trustChainTheme`.

### Colour tokens

These are the semantic colours used throughout the app:

| Token       | Value     | Used for                        |
| ----------- | --------- | ------------------------------- |
| `primary`   | `#238636` | Primary actions, create buttons |
| `secondary` | `#1f6feb` | Secondary actions, links        |
| `error`     | `#f85149` | Errors, destructive actions     |
| `success`   | `#3fb950` | Success messages, active state  |
| `warning`   | `#d29922` | Warnings, in-transit status     |
| `info`      | `#58a6ff` | Informational messages          |

There are also status-specific colours: `status-produced`, `status-stored`, `status-in-transit`, etc. These map directly to the `STATUS_COLORS` object in `useBatches.js`.

### Using colours in components

```vue
<!-- Named colour token -->
<v-btn color="primary">Create</v-btn>
<v-chip color="error">Recalled</v-chip>

<!-- Dynamic colour from data -->
<v-chip :color="STATUS_COLORS[batch.status]">{{ batch.status }}</v-chip>
```

### Icons

Icons come from the **Material Design Icons** (`@mdi/font`) set. The prefix is always `mdi-`:

```vue
<v-icon icon="mdi-truck" />
<v-btn prepend-icon="mdi-plus-circle">Create</v-btn>
```

Browse all icons at [materialdesignicons.com](https://materialdesignicons.com).

---

## 13. Environment Variables

All environment variables used by Vite must be prefixed with `VITE_` to be accessible in the browser.

| Variable                | Required | Default                 | Description                                  |
| ----------------------- | -------- | ----------------------- | -------------------------------------------- |
| `VITE_CONTRACT_ADDRESS` | **Yes**  | —                       | Deployed TrustChain contract address         |
| `VITE_CHAIN_ID`         | No       | `0x7a69`                | Chain ID in hex (Anvil = `31337` = `0x7a69`) |
| `VITE_CHAIN_NAME`       | No       | `Anvil Local`           | Display name shown in MetaMask               |
| `VITE_RPC_URL`          | No       | `http://127.0.0.1:8545` | JSON-RPC endpoint                            |

In code, they are accessed via `import.meta.env.VITE_*`:

```js
const CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS;
```

**Never commit `.env` to git.** Only `.env.example` is committed. `.env` is in `.gitignore`.

---

## 14. Common Patterns You Will See

### Pattern 1: Loading + Error + Toast in composables

Every write function in the composables follows this exact structure:

```js
async function doSomething() {
  loading.value = true;
  error.value = null;
  try {
    const tx = await getContract().someMethod(args);
    await tx.wait();
    toast.show("Done!", "success");
    return true;
  } catch (err) {
    const msg = parseContractError(err);
    error.value = msg;
    toast.show(msg, "error");
    return false;
  } finally {
    loading.value = false; // always runs, even if an error was thrown
  }
}
```

### Pattern 2: Binding loading to a button

```vue
<v-btn :loading="loading" @click="doSomething">Submit</v-btn>
```

When `loading` is `true`, Vuetify shows a spinner and disables the button automatically.

### Pattern 3: Conditional rendering by role

```vue
<template v-if="roleLabel === 'ADMIN'">
  <!-- Admin-only content -->
</template>
```

Or with computed helpers (as seen in `DashboardView.vue`):

```js
const isAdmin = computed(() => roleLabel.value === "ADMIN");
const isProducer = computed(() => roleLabel.value === "PRODUCER");
```

### Pattern 4: Emitting from forms

Components that wrap forms emit an event when the action succeeds:

```js
// Inside the component
const emit = defineEmits(["created"]);
// ...
if (ok) emit("created", serialNumber);
```

```vue
<!-- In the parent -->
<BatchForm @created="onBatchCreated" />
```

### Pattern 5: `Promise.all` for parallel reads

When a view needs multiple independent pieces of data, fetch them in parallel:

```js
onMounted(async () => {
  [productTypes.value, units.value, batch.value] = await Promise.all([
    admin.getProductTypes(),
    admin.getUnits(),
    fetchBatch(serial.value),
  ]);
});
```

The leading `;` before the destructuring assignment is intentional — it prevents the JavaScript parser from treating the `[` as a property access on the previous statement.

### Pattern 6: `storeToRefs` for reactive store properties

When you need reactive refs from a Pinia store (to pass to `watch` or use in templates), use `storeToRefs`:

```js
import { storeToRefs } from "pinia";
import { useWalletStore } from "@/stores/wallet";

const wallet = useWalletStore();
const { account, contract } = storeToRefs(wallet);
// account and contract are now reactive refs that work with watch()
```

**Do NOT** destructure directly (`const { account } = wallet`) — this would break reactivity.

---

## 15. Glossary

| Term                 | Meaning                                                                            |
| -------------------- | ---------------------------------------------------------------------------------- |
| **DApp**             | Decentralised Application — a web app backed by a smart contract                   |
| **Wallet**           | A browser extension (MetaMask) that holds private keys and signs transactions      |
| **Account**          | An Ethereum address (e.g. `0xabc...1234`), tied to a wallet                        |
| **Contract**         | A deployed smart contract. We interact with it via Ethers.js                       |
| **ABI**              | Application Binary Interface — describes all the methods a contract exposes        |
| **Transaction (tx)** | A signed message sent to the blockchain to change state. Costs gas.                |
| **Gas**              | Fee paid in ETH to execute a transaction                                           |
| **Block**            | A group of transactions added to the chain. Mining = adding a block.               |
| **bytes32**          | A Solidity type for fixed-length 32-byte data (used for serial numbers, names)     |
| **Composable**       | A Vue 3 `use*` function that encapsulates reactive state and logic                 |
| **Pinia Store**      | A global reactive store (similar to Vuex, but simpler)                             |
| **Reactive ref**     | A Vue value wrapped in `ref()` — accessing `.value` gives the current value        |
| **`<script setup>`** | Vue 3's shorthand Composition API syntax — the recommended way to write components |
| **Navigation Guard** | A function that runs before routing to check permissions                           |
| **Emit**             | How a child component sends events to its parent                                   |
| **Props**            | Data passed from a parent component to a child component                           |
