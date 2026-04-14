# TrustChain — Supply Chain Traceability System
## Design Specification

**Course:** Advanced Cryptographic and Security Technologies  
**Date:** 2026-04-15  
**Tech Stack:** Solidity 0.8.28 · Foundry · Vue 3 · Vuetify 4 · Pinia · ethers.js v6 · Anvil

---

## 1. Problem Statement

Traditional supply chains lack transparency — stakeholders cannot independently verify where a
product has been, who handled it, or whether it has been tampered with. Blockchain technology
solves this by providing an immutable, shared audit trail accessible to all authorised parties.

This system tracks product batches (food, pharmaceuticals, industrial goods) from production to
final distribution using smart contracts. Every state transition is recorded on-chain as an
immutable event, enabling full traceability, fraud prevention, and regulatory oversight.

---

## 2. Project Structure

```
trust-chain/
├── contracts/                    # self-contained Foundry project
│   ├── src/
│   │   ├── interfaces/
│   │   │   └── ITrustChain.sol   # function signatures + events
│   │   ├── DataTypes.sol         # enums + structs (no logic)
│   │   └── TrustChain.sol        # single main contract
│   ├── test/
│   │   └── TrustChain.t.sol      # Forge test suite
│   ├── script/
│   │   └── Deploy.s.sol          # Anvil deployment script
│   ├── lib/                      # forge dependencies
│   ├── out/                      # compiled artifacts (gitignored)
│   └── foundry.toml
├── ui/                           # Vue 3 frontend
│   ├── src/
│   │   ├── views/                # 4 routes
│   │   ├── components/           # reusable UI components
│   │   ├── composables/          # contract interaction logic
│   │   ├── stores/               # Pinia state
│   │   ├── router/               # role-based routing
│   │   └── contracts/            # ABI import
│   ├── vite.config.js
│   └── package.json
├── docs/                         # this folder
└── .devcontainer/                # VS Code dev container (Foundry + Node 20)
```

**Design decision:** `foundry.toml` lives inside `contracts/` — that directory is a fully
self-contained Foundry project. Running `forge` commands from `contracts/` requires no path
configuration. The `ui/` Vite config imports the compiled ABI artifact via a relative alias:
`'@trustchain-abi': '../contracts/out/TrustChain.sol/TrustChain.json'`

---

## 3. Roles

Six fixed roles encoded as a Solidity enum. Custom RBAC (not OpenZeppelin) — roles are
fixed at design time, making a simple enum cleaner than OZ's dynamic bytes32 role system.

| Role | Responsibilities |
|---|---|
| `ADMIN` | Register users, manage product type + unit registries |
| `PRODUCER` | Create product batches |
| `TRANSPORTER` | Ship batches (STORED → IN_TRANSIT) |
| `WAREHOUSE` | Receive batches, dispose recalled goods |
| `DISTRIBUTOR` | Final distribution to point of sale |
| `AUDITOR` | Full read access, recall batches, certify batches |

The deployer of the contract automatically becomes the first `ADMIN`.

---

## 4. Data Model

### 4.1 User Struct

```solidity
struct User {
    address ethAddress;
    Role    role;
    bool    isActive;
    uint48  registeredAt;
}
```

Deactivated users (`isActive = false`) are locked out of all state-changing functions.

### 4.2 Dynamic Registries

Product types and units are admin-managed at runtime — not fixed enums.
This allows new categories to be added without redeploying the contract.

**Pattern (identical for both):**
```solidity
uint8                       public productTypeCount;
mapping(uint8  => string)   public productTypeNames;   // id → "FOOD"
mapping(string => uint8)    public productTypeIds;     // "FOOD" → id

uint8                       public unitCount;
mapping(uint8  => string)   public unitNames;
mapping(string => uint8)    public unitIds;
```

Batches store `uint8 productTypeId` and `uint8 unitId` — 1 byte each, same gas cost as an enum.

**Pre-seeded product types:** FOOD, PHARMA, INDUSTRIAL, ELECTRONICS, AGRICULTURE, CHEMICAL, TEXTILE  
**Pre-seeded units:** KG, G, TON, L, ML, PCS, M2

### 4.3 Batch Struct

Storage-optimised for minimum SLOAD/SSTORE operations. 6 storage slots total.

```solidity
struct Batch {
    // Slot 0 — 32 bytes
    uint256  id;                  // auto-increment

    // Slot 1 — 32 bytes exactly (perfectly packed)
    uint128  quantity;            // 16 bytes
    uint48   creationDate;        //  6 bytes — unix timestamp
    uint48   expiryDate;          //  6 bytes — 0 = no expiry
    uint8    productTypeId;       //  1 byte  — dynamic registry index
    Category category;            //  1 byte  — fixed enum
    Status   status;              //  1 byte  — lifecycle state
    bool     recalled;            //  1 byte  — permanent, never unset

    // Slot 2 — 22 bytes used
    address  producer;            // 20 bytes — immutable after creation
    uint8    unitId;              //  1 byte  — dynamic registry index
    bool     certified;           //  1 byte  — set by AUDITOR

    // Slot 3 — 20 bytes used
    address  currentHolder;       // 20 bytes — updated on every transition

    // Slot 4 — 32 bytes
    bytes32  origin;              // production region (e.g. "GR-PEL")

    // Slot 5 — 32 bytes
    bytes32  serialNumber;        // human-readable ID (e.g. "OLIVE-GR-001")
}
```

**Slot 1 packing rationale:** `recalled` lives in the same slot as `status` — both are read
on every transition check, so they share a single SLOAD.

**Location is NOT in the struct.** Transit locations are captured only in `BatchTransitioned`
events. This avoids an extra SSTORE on every transition (~5,000 gas saved per hop) while
preserving the complete location history in the immutable event log.

### 4.4 Category Enum

Fixed — handling categories are defined by logistics/regulatory standards, not business domain.
`OTHER` is always included on fixed enums as an escape hatch.

```solidity
enum Category { PERISHABLE, REFRIGERATED, HAZARDOUS, NON_PERISHABLE, FRAGILE, OTHER }
```

---

## 5. Lifecycle State Machine

Multi-hop model — a batch can move through storage and transit multiple times before
reaching its final destination, reflecting real-world supply chain logistics.

### 5.1 States

```solidity
enum Status { PRODUCED, STORED, IN_TRANSIT, DISTRIBUTED, RECALLED, DISPOSED }
```

- `DISTRIBUTED` — terminal state, normal forward chain end
- `DISPOSED` — terminal state, reverse chain end (recalled goods only)

### 5.2 Allowed Transitions

```
PRODUCED    → STORED       (WAREHOUSE receives from producer)
PRODUCED    → IN_TRANSIT   (TRANSPORTER picks up directly from producer)
STORED      → IN_TRANSIT   (TRANSPORTER picks up from warehouse)
STORED      → DISTRIBUTED  (DISTRIBUTOR collects from warehouse)
STORED      → DISPOSED     (WAREHOUSE disposes — requires recalled=true)
IN_TRANSIT  → STORED       (WAREHOUSE receives at intermediate hub)
IN_TRANSIT  → DISTRIBUTED  (DISTRIBUTOR receives final delivery)
DISTRIBUTED → RECALLED     (AUDITOR triggers recall — sets recalled=true permanently)
RECALLED    → STORED       (WAREHOUSE collects recalled goods — reverse logistics)
```

**Blocked transitions:**
- Any → self (meaningless)
- Any → PRODUCED (cannot un-produce)
- DISTRIBUTED → anything except RECALLED
- RECALLED → IN_TRANSIT / DISTRIBUTED (recalled goods cannot re-enter forward chain)
- `distributeBatch` checks `!batch.recalled` — if `recalled=true`, distribution is blocked even after state machine allows the transition

### 5.3 Transition Matrix (constructor)

```solidity
mapping(Status => mapping(Status => bool)) public allowedTransitions;
```

Initialised in constructor. Every lifecycle function calls:
```solidity
if (!allowedTransitions[batch.status][newStatus]) revert InvalidTransition(batch.status, newStatus);
```

### 5.4 Visual State Diagram

```
                    ┌─────────────┐
                    │  PRODUCED   │ ← createBatch (PRODUCER)
                    └──────┬──────┘
               ┌───────────┴────────────┐
               ▼                        ▼
        ┌─────────────┐         ┌─────────────┐
        │   STORED    │◄────────│  IN_TRANSIT │
        └──────┬──────┘         └──────┬──────┘
               │  ╲                    │
               │   ╲                   │
               ▼    ╲                  ▼
        ┌─────────────┐ ◄─────── ┌─────────────┐
        │ DISTRIBUTED │          │             │
        └──────┬──────┘          └─────────────┘
               │
               ▼
        ┌─────────────┐
        │  RECALLED   │  recalled=true (permanent)
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │   STORED    │  (reverse logistics)
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │  DISPOSED   │  terminal
        └─────────────┘
```

---

## 6. Smart Contract — Functions

### Admin Domain

| Function | Access | Description |
|---|---|---|
| `registerUser(address, Role)` | onlyAdmin | Register new user with role |
| `deactivateUser(address)` | onlyAdmin | Lock user out (isActive=false) |
| `activateUser(address)` | onlyAdmin | Re-enable user |
| `addProductType(string)` | onlyAdmin | Add to product type registry |
| `addUnit(string)` | onlyAdmin | Add to unit registry |

### Batch Domain

| Function | Access | Description |
|---|---|---|
| `createBatch(serial, productTypeId, category, unitId, quantity, origin, expiryDate)` | onlyProducer | Creates batch in PRODUCED state |
| `getBatch(uint256 id)` | view | Returns full Batch struct |
| `getBatchBySerial(bytes32)` | view | Lookup by serial number |

### Lifecycle Domain

| Function | Access | Transition |
|---|---|---|
| `receiveBatch(serial, location)` | onlyWarehouse | PRODUCED/IN_TRANSIT/RECALLED → STORED |
| `shipBatch(serial, location)` | onlyTransporter | STORED → IN_TRANSIT |
| `distributeBatch(serial, location)` | onlyDistributor | STORED/IN_TRANSIT → DISTRIBUTED (blocked if recalled) |
| `recallBatch(serial, location)` | onlyAuditor | DISTRIBUTED → RECALLED, sets recalled=true |
| `certifyBatch(serial)` | onlyAuditor | Sets certified=true |
| `disposeBatch(serial, location)` | onlyWarehouse | STORED → DISPOSED (requires recalled=true) |

### View Domain

| Function | Access | Returns |
|---|---|---|
| `getUser(address)` | view | User struct |
| `getProductTypes()` | view | All registered product type names |
| `getUnits()` | view | All registered unit names |

---

## 7. Modifiers and Errors

### Named Modifiers (assignment requirement)

```solidity
modifier onlyAdmin()       { _requireRole(msg.sender, Role.ADMIN);       _; }
modifier onlyProducer()    { _requireRole(msg.sender, Role.PRODUCER);    _; }
modifier onlyTransporter() { _requireRole(msg.sender, Role.TRANSPORTER); _; }
modifier onlyWarehouse()   { _requireRole(msg.sender, Role.WAREHOUSE);   _; }
modifier onlyDistributor() { _requireRole(msg.sender, Role.DISTRIBUTOR); _; }
modifier onlyAuditor()     { _requireRole(msg.sender, Role.AUDITOR);     _; }
```

All backed by `_requireRole(address, Role) internal` — checks `isActive == true` AND
correct role. Reverts with `Unauthorized()` on failure.

### Custom Errors (cheaper than require strings)

```solidity
error ZeroAddress();
error AlreadyRegistered();
error NotRegistered();
error Unauthorized();
error BatchNotFound();
error DuplicateSerial();
error InvalidTransition(Status from, Status to);
error CannotDistributeRecalled();
error BatchNotRecalled();
```

---

## 8. Events (Audit Trail)

```solidity
event UserRegistered(
    address indexed user,
    Role            role
);

event BatchCreated(
    uint256 indexed batchId,
    bytes32 indexed serialNumber,
    address indexed producer
);

event BatchTransitioned(
    uint256 indexed batchId,
    Status  indexed from,
    Status  indexed to,
    bytes32         location,   // where the transition happened
    address         by,         // who executed it
    uint48          at          // block.timestamp
);

event BatchCertified(
    uint256 indexed batchId,
    address indexed auditor
);

event BatchRecalled(
    uint256 indexed batchId,
    address indexed auditor
);
```

`BatchTransitioned` is the single event covering all lifecycle moves. The frontend
reconstructs the complete route by querying all `BatchTransitioned` events for a given
`batchId` — each event is a hop in the journey with location, actor, and timestamp.

---

## 9. Frontend Architecture

### Routes

| Route | View | Access |
|---|---|---|
| `/` | HomeView | public |
| `/dashboard` | DashboardView | any registered user |
| `/batch/:id` | BatchDetailView | any registered user |
| `/search` | SearchView | any registered user |

Navigation guard in `router/index.js` calls `contract.getUser(account)` and redirects
unregistered addresses to `/` with an explanatory message.

### Views

**HomeView** — landing page, wallet connect button, role display after connection.

**DashboardView** — single role-aware view replacing 6 per-role views:
- ADMIN section: register users, add product types, add units
- PRODUCER section: create batch form
- WAREHOUSE section: receive batch, dispose recalled batch
- TRANSPORTER section: ship batch
- DISTRIBUTOR section: distribute batch
- AUDITOR section: recall batch, certify batch + full batch list
- All roles: list of batches relevant to their role (event-filtered)

**BatchDetailView** — most important view for the demo:
- Full batch data (type, category, quantity, unit, origin, status, certified, recalled flags)
- `BatchTimeline` component: reconstructed from `BatchTransitioned` events,
  each hop shows from→to status, location, actor address, formatted timestamp

**SearchView** — search by serial number (`bytes32`) or numeric ID (`uint256`),
displays `BatchCard` component with current status.

### Component Tree

```
App.vue
├── common/WalletConnect.vue      — connect/disconnect button
├── common/RoleBadge.vue          — displays role as coloured chip
├── batch/BatchCard.vue           — compact batch summary
├── batch/BatchForm.vue           — create batch form (producer)
├── batch/BatchTimeline.vue       — event-driven route history
└── admin/UserForm.vue            — register user form (admin)
```

### Composables

**`useUserRole.js`** — fetches and decodes user role from contract on each account change.
Exports `role`, `roleLabel`, `isLoading`, `fetchRole()`.

**`useBatches.js`** — all batch contract interactions:
- `createBatch(params)` — calls contract, awaits receipt
- `receiveBatch(serial, location)` / `shipBatch` / `distributeBatch` / `recallBatch` / `certifyBatch` / `disposeBatch`
- `fetchBatch(id)` — reads Batch struct
- `fetchBatchBySerial(serial)` — reverse lookup
- `fetchBatchTimeline(batchId)` — queries all `BatchTransitioned` events for a batch
- `fetchMyBatches()` — role-filtered event queries (e.g. PRODUCER queries BatchCreated where producer==me)

**`useAdmin.js`** — admin + registry interactions:
- `registerUser(address, role)` / `deactivateUser` / `activateUser`
- `addProductType(name)` / `addUnit(name)`
- `getProductTypes()` / `getUnits()`

### wallet.js (Pinia store)

```
state:   account, contract, error
getters: isConnected
actions: connect(), disconnect()
```

`connect()` flow:
1. `eth_requestAccounts` — prompt MetaMask
2. Switch to Anvil chain (chainId 31337) — add chain if not known
3. `BrowserProvider → getSigner() → new Contract(address, ABI, signer)`
4. Register `accountsChanged` + `chainChanged` listeners
5. Store contract as `markRaw()` (prevent Pinia reactivity overhead)

---

## 10. Security Design

### Access Control
- Every state-changing function has a named modifier
- `_requireRole` checks both `isActive` AND correct `Role`
- Deactivated users are fully locked out — no role check passes
- Transition matrix enforced on every lifecycle call

### Recall Protection
- `recalled=true` is set atomically in `recallBatch` and never unset
- `distributeBatch` explicitly checks `if (batch.recalled) revert CannotDistributeRecalled()`
- `disposeBatch` checks `if (!batch.recalled) revert BatchNotRecalled()`
- These checks are in addition to the transition matrix

### Audit Trail
- All critical actions emit events — tamper-proof, immutable
- Events cannot be deleted or modified after emission
- Full batch route history reconstructable from events alone

### No Personal Data On-chain
- User struct stores only `address`, `role`, `isActive`, `registeredAt`
- No names, emails, or personal identifiers on-chain

### Security Audit Tools
Run after implementation from `contracts/`:
```bash
slither src/TrustChain.sol            # vulnerability detection
solhint "src/**/*.sol"                # linting + best practices
```

Expected findings to verify:
- No reentrancy (no ETH transfers, no external calls)
- No integer overflow (Solidity 0.8.x built-in protection)
- Access control: every function has correct modifier
- No uninitialized state (constructor seeds all registries and transition matrix)

---

## 11. Test Data Requirements

### Minimum 10 Batches

| Serial | Product Type | Category | Status |
|---|---|---|---|
| OLIVE-GR-001 | FOOD | PERISHABLE | full workflow |
| PHARMA-DE-001 | PHARMA | REFRIGERATED | full workflow with recall |
| STEEL-DE-001 | INDUSTRIAL | NON_PERISHABLE | STORED |
| COTTON-EG-001 | TEXTILE | NON_PERISHABLE | IN_TRANSIT |
| CHIP-TW-001 | ELECTRONICS | FRAGILE | PRODUCED |
| ACID-CN-001 | CHEMICAL | HAZARDOUS | STORED |
| GRAIN-UA-001 | AGRICULTURE | PERISHABLE | DISTRIBUTED |
| MOTOR-JP-001 | INDUSTRIAL | NON_PERISHABLE | IN_TRANSIT |
| VACCINE-US-001 | PHARMA | REFRIGERATED | STORED |
| WINE-FR-001 | FOOD | PERISHABLE | DISTRIBUTED |

### Workflow 1 — Normal forward chain (olive oil)
```
OLIVE-GR-001: PRODUCED (Athens, Producer)
           → STORED       (Athens Warehouse, location: "Athens Cold Hub")
           → IN_TRANSIT   (Piraeus Port, location: "Piraeus Port")
           → STORED       (Hamburg Hub, location: "Hamburg Warehouse")
           → IN_TRANSIT   (Final truck, location: "Hamburg → Berlin")
           → DISTRIBUTED  (Berlin Supermarket, location: "Berlin Retail")
```

### Workflow 2 — Recall + reverse logistics (pharma)
```
PHARMA-DE-001: PRODUCED   (Frankfurt, Producer)
            → STORED      (Frankfurt Pharma Hub)
            → IN_TRANSIT  (Air freight)
            → DISTRIBUTED (Athens Pharmacy)
            → RECALLED    (Auditor: contamination found)
            → STORED      (Athens Returns Warehouse)
            → DISPOSED    (Disposal facility)
```

---

## 12. Deployment

Local development against Anvil:
```bash
# Terminal 1 — start local blockchain
anvil

# Terminal 2 — deploy contract
cd contracts && forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Terminal 3 — start frontend
cd ui && npm run dev
```

MetaMask configuration:
- Network: Localhost 8545
- Chain ID: 31337
- Use Anvil's pre-funded accounts for testing

---

## 13. Deliverables Checklist

- [ ] `contracts/src/DataTypes.sol` — enums + structs
- [ ] `contracts/src/interfaces/ITrustChain.sol` — interface
- [ ] `contracts/src/TrustChain.sol` — main contract with comments
- [ ] `contracts/test/TrustChain.t.sol` — Forge test suite (all green)
- [ ] `contracts/script/Deploy.s.sol` — deployment script
- [ ] `ui/` — complete Vue 3 frontend
- [ ] `.devcontainer/` — VS Code dev container
- [ ] Slither + Solhint audit run, findings documented
- [ ] 10+ batches registered in demo
- [ ] 2 complete end-to-end workflows demonstrated
- [ ] PDF report with architecture, screenshots, security audit findings
