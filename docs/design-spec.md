# TrustChain — Supply Chain Traceability System
## Design Specification

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
│   │   ├── DataTypes.sol         # enums + structs (no logic)
│   │   ├── ITrustChain.sol       # interface — function signatures + events + errors
│   │   └── TrustChain.sol        # single main contract
│   ├── test/
│   │   └── TrustChain.t.sol      # Forge test suite
│   ├── script/
│   │   └── Deploy.s.sol          # Anvil deployment script
│   ├── lib/                      # forge dependencies (forge-std)
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
└── .devcontainer/                # VS Code dev container (Foundry + Node 24)
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
    // Slot 0 — 28 bytes used
    address ethAddress;
    Role    role;
    bool    isActive;
    uint48  registeredAt;

    // Slot 1 — 32 bytes
    bytes32 name;         // short identifier (e.g. "Athens Producer")
}
```

The `name` field stores a short identifier (not PII) — satisfies the assignment's user struct
requirement while keeping the on-chain footprint minimal (2 storage slots per user).

Deactivated users (`isActive = false`) are locked out of all state-changing functions.

### 4.2 Dynamic Registries

Product types and units are admin-managed at runtime — not fixed enums.
This allows new categories to be added without redeploying the contract.

**Pattern (identical for both):**
```solidity
uint8                       public productTypeCount;
mapping(uint8 => string)    public productTypeNames;   // id → "FOOD"

uint8                       public unitCount;
mapping(uint8 => string)    public unitNames;          // id → "KG"
```

Batches store `uint8 productTypeId` and `uint8 unitId` — 1 byte each, same gas cost as an enum.

**One-way mapping by design.** Earlier drafts included reverse lookups (`productTypeIds: name → id`),
but those maps were never read on-chain. The frontend gets the name↔id mapping implicitly from
the array returned by `getProductTypes()` — array index *is* the id. Removing the reverse
mapping saves one SSTORE per add (~20k gas) and simplifies the UI (one contract call instead
of two per form submit).

**Pre-seeded product types:** FOOD, PHARMA, INDUSTRIAL, ELECTRONICS, AGRICULTURE, CHEMICAL, TEXTILE  
**Pre-seeded units:** KG, G, TON, L, ML, PCS, M2

### 4.3 Batch Struct

Storage-optimised for minimum SLOAD/SSTORE operations. 5 storage slots total.
`serialNumber` is the canonical key — the `batches` mapping is keyed by `bytes32`,
not by an internal counter. No separate `uint256 id` field.

```solidity
struct Batch {
    // Slot 0 — 32 bytes exactly (perfectly packed)
    uint128  quantity;            // 16 bytes
    uint48   creationDate;        //  6 bytes — unix timestamp
    uint48   expiryDate;          //  6 bytes — 0 = no expiry
    uint8    productTypeId;       //  1 byte  — dynamic registry index
    Category category;            //  1 byte  — fixed enum
    Status   status;              //  1 byte  — lifecycle state
    bool     recalled;            //  1 byte  — permanent, never unset

    // Slot 1 — 22 bytes used
    address  producer;            // 20 bytes — immutable after creation
    uint8    unitId;              //  1 byte  — dynamic registry index
    bool     certified;           //  1 byte  — set by AUDITOR

    // Slot 2 — 20 bytes used
    address  currentHolder;       // 20 bytes — updated on every transition

    // Slot 3 — 32 bytes
    bytes32  origin;              // production region (e.g. "GR-PEL")

    // Slot 4 — 32 bytes
    bytes32  serialNumber;        // canonical key (e.g. "OLIVE-GR-001")
}
```

**Slot 0 packing rationale:** `recalled` lives in the same slot as `status` — both are read
on every transition check, so they share a single SLOAD.

**Single-key design rationale:** Earlier drafts had both a `uint256 id` (auto-increment) and
a `bytes32 serialNumber`, with a `serialToBatchId` mapping bridging them. In practice we never
use the numeric id for anything (no ordering logic, no range queries), so it's pure ceremony.
Keying `batches` directly by `serialNumber` removes the bridge mapping, the counter, and one
struct field — net savings: one SSTORE per batch creation plus a cleaner event surface.

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
mapping(Status => mapping(Status => bool)) private allowedTransitions;
```

Initialised in constructor and never mutated. Private — the mapping encodes business logic,
not configurable state. Every lifecycle function calls via `_transition()`:
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
| `registerUser(address, bytes32 name, Role)` | onlyAdmin | Register new user with role |
| `deactivateUser(address)` | onlyAdmin | Lock user out (isActive=false) |
| `activateUser(address)` | onlyAdmin | Re-enable user |
| `addProductType(string)` | onlyAdmin | Add to product type registry |
| `addUnit(string)` | onlyAdmin | Add to unit registry |

### Batch Domain

| Function | Access | Description |
|---|---|---|
| `createBatch(serial, productTypeId, category, unitId, quantity, origin, expiryDate)` | onlyProducer | Creates batch in PRODUCED state |
| `getBatch(bytes32 serialNumber)` | view | Returns full Batch struct |

### Lifecycle Domain

| Function | Access | Description |
|---|---|---|
| `proposeCustody(serial, newHolder)` | active currentHolder | Step 1 of the handoff: offers custody to the next actor (custody does not move yet; sets `pendingHolder`) |
| `acceptCustody(serial)` | active pendingHolder | Step 2: the proposed recipient accepts and custody moves |
| `cancelCustody(serial)` | active currentHolder | Retracts a pending custody offer before it is accepted |
| `receiveBatch(serial, location)` | onlyWarehouse (must be currentHolder) | PRODUCED/IN_TRANSIT/RECALLED → STORED |
| `shipBatch(serial, location)` | onlyTransporter (must be currentHolder) | PRODUCED/STORED → IN_TRANSIT |
| `distributeBatch(serial, location)` | onlyDistributor (must be currentHolder) | STORED/IN_TRANSIT → DISTRIBUTED (blocked if recalled) |
| `recallBatch(serial, location)` | onlyAuditor | any → RECALLED, sets recalled=true permanently; auditor becomes currentHolder |
| `certifyBatch(serial)` | onlyAuditor | Sets certified=true (batch must be DISTRIBUTED) |
| `disposeBatch(serial, location)` | onlyWarehouse (must be currentHolder) | STORED → DISPOSED (requires recalled=true) |

### View Domain

| Function | Access | Returns |
|---|---|---|
| `getUser(address)` | view | User struct |
| `getProductTypes()` | view | All registered product type names |
| `getUnits()` | view | All registered unit names |

---

## 7. Modifiers and Errors

### Named Modifiers

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
error SelfDeactivation();       // admin cannot deactivate themselves
error Unauthorized();
error BatchNotFound();
error DuplicateSerial();
error InvalidSerialNumber();    // zero bytes32
error InvalidQuantity();        // zero quantity
error InvalidOrigin();          // zero bytes32
error InvalidExpiryDate();      // expiry already in the past
error InvalidProductType();     // productTypeId >= productTypeCount
error InvalidUnit();            // unitId >= unitCount
error DuplicateProductType();
error DuplicateUnit();
error NotCurrentHolder();       // caller is not the currentHolder
error BatchExpired();           // expiry enforced on forward commerce transitions
error InvalidTransition(Status from, Status to);
error CannotDistributeRecalled();
error BatchNotRecalled();
error AlreadyCertified();
error CannotCertifyInStatus(Status current);
```

**Trust boundaries and input validation.** The `PRODUCER` role is trusted for *intent*
(only producers can create batches) but **not** for *input correctness*. A producer could
bypass the UI and submit a `productTypeId` or `unitId` that doesn't map to any registered
entry, leaving garbage data on-chain. `createBatch` therefore validates both ids against
`productTypeCount` / `unitCount` before writing state. Two warm SLOADs, two reverts —
cheap defence against malformed input.

---

## 8. Events (Audit Trail)

```solidity
event UserRegistered(
    address indexed user,
    bytes32         name,
    Role            role
);

event UserDeactivated(address indexed user);
event UserActivated(address indexed user);
event ProductTypeAdded(uint8 indexed id, string name);
event UnitAdded(uint8 indexed id, string name);

event BatchCreated(
    bytes32 indexed serialNumber,
    address indexed producer
);

event BatchTransitioned(
    bytes32 indexed serialNumber,
    Status  indexed from,
    Status  indexed to,
    bytes32         location,   // where the transition happened
    address         by,         // who executed it
    uint48          at          // block.timestamp
);

event BatchCertified(
    bytes32 indexed serialNumber,
    address indexed auditor
);

event BatchRecalled(
    bytes32 indexed serialNumber,
    address indexed auditor
);

event CustodyProposed(
    bytes32 indexed serialNumber,
    address indexed from,
    address indexed to
);

event CustodyCancelled(
    bytes32 indexed serialNumber,
    address indexed from,
    address indexed to
);

event CustodyDeclined(
    bytes32 indexed serialNumber,
    address indexed from,
    address indexed to
);

event CustodyTransferred(
    bytes32 indexed serialNumber,
    address indexed from,
    address indexed to
);
```

`BatchTransitioned` is the single event covering all lifecycle moves. The frontend
reconstructs the complete route by querying `BatchCreated` (first timeline entry) plus all
`BatchTransitioned` events for a given `serialNumber` — each event is a hop in the journey
with location, actor, and timestamp.

---

## 9. Frontend Architecture

### Routes

| Route | View | Access |
|---|---|---|
| `/` | HomeView | public |
| `/dashboard` | DashboardView | any registered user |
| `/batch/:serial` | BatchDetailView | any registered user |
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

**SearchView** — search by serial number (`bytes32`),
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

**`useBatches.js`** — batch reads and writes. *Writes* call the contract through ethers
and await the receipt; *reads* query the Goldsky subgraph (see **Data reads** below) and
then read any live field back from the contract for authority:
- writes: `createBatch` · `receiveBatch` / `shipBatch` / `distributeBatch` / `recallBatch` / `disposeBatch` / `certifyBatch`
- custody handshake (two-phase): `proposeCustody` / `acceptCustody` / `cancelCustody` / `declineCustody`
- `fetchBatch(serial)` — reads the `Batch` struct directly from the contract
- `fetchMyBatches()` / `fetchAllBatches()` — subgraph `batchCreateds` → `getBatch` per serial
- `fetchPendingCustody()` / `fetchOutgoingCustody()` — subgraph `custodyProposeds`, each confirmed still live via the `pendingHolder` getter
- `fetchBatchTimeline(serial)` — one subgraph query across all batch + custody events (`BatchCreated`, `BatchTransitioned`, `CustodyProposed/Cancelled/Declined/Transferred`, `BatchCertified`)

### Data reads — Goldsky subgraph

On a testnet deployment the UI does **not** scan events from the RPC. A Goldsky
[Instant Subgraph](https://goldsky.com/) indexes the contract's events and exposes them
over GraphQL (`ui/src/utils/graphql.js`, endpoint `VITE_SUBGRAPH_URL`). The read helpers
use the subgraph to discover *which* serials are relevant, then read mutable state
(`getBatch`, `pendingHolder`) from the contract so values are always authoritative —
the subgraph is an index, never the source of truth.

**`useAdmin.js`** — admin + registry interactions:
- `registerUser(address, name, role)` / `deactivateUser` / `activateUser`
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
2. Switch to the configured chain (`VITE_CHAIN_ID` — e.g. Anvil 31337 or Sepolia 0xaa36a7) — add chain if not known
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

### Chain-of-Custody Enforcement
- `currentHolder` is tracked on every `Batch` struct
- Changing holder is a two-phase handshake: `proposeCustody(serial, newHolder)` (caller must be the active currentHolder) then `acceptCustody(serial)` (caller must be the active pendingHolder). Custody only moves on accept. The handshake is symmetric: `cancelCustody` lets the holder retract a pending offer and `declineCustody` lets the proposed recipient reject it; any status transition also clears a stale offer.
- Both legs assert the caller is active, so a deactivated holder can neither propose nor accept a handoff
- Every lifecycle function (`shipBatch`, `receiveBatch`, `distributeBatch`, `disposeBatch`) also asserts `currentHolder == msg.sender` before transitioning
- `recallBatch` is exempt from the handshake — auditor override; after the call the auditor becomes currentHolder, then proposes custody to a warehouse (which accepts) before the warehouse can dispose

### Expiry Enforcement
- `_transition()` checks `expiryDate` before every state change
- Blocked for forward commerce: if `expiryDate != 0 && expiryDate < block.timestamp` and the transition is not part of reverse logistics
- Exempt for reverse logistics: any transition to `RECALLED`, any transition to `DISPOSED`, and any transition originating from `RECALLED` status (so quarantined goods can still be received into storage)

### Recall Protection
- `recalled=true` is set atomically in `recallBatch` and never unset
- `distributeBatch` explicitly checks `if (batch.recalled) revert CannotDistributeRecalled()`
- `disposeBatch` checks `if (!batch.recalled) revert BatchNotRecalled()`
- These checks are in addition to the transition matrix

### Audit Trail
- All critical actions emit events — UserRegistered, UserDeactivated, UserActivated,
  ProductTypeAdded, UnitAdded, BatchCreated, BatchTransitioned, BatchCertified, BatchRecalled
- Events are tamper-proof, immutable
- Events cannot be deleted or modified after emission
- Full batch route history reconstructable from events alone

### Minimal Personal Data On-chain
- User struct stores `address`, `role`, `isActive`, `registeredAt`, `name` (bytes32)
- `name` is a short operational identifier (e.g. "Athens Producer"), not PII
- No emails, phone numbers, or personal identifiers on-chain

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

## 11. Example Workflows

Two concrete paths through the state machine, both seeded by the deploy script.
See [deployment.md](deployment.md#what-the-deploy-script-creates) for the full demo dataset.

### Workflow 1 — Normal forward chain (olive oil)
```
OLIVE-GR-001: PRODUCED
           → STORED       (WH-KALAMATA — origin warehouse)
           → IN_TRANSIT   (TRUCK-001   — first leg)
           → STORED       (WH-ATHENS   — hub warehouse)
           → IN_TRANSIT   (TRUCK-002   — final leg)
           → DISTRIBUTED  (DIST-PIR)
           → certified    (auditor certifies after successful delivery)
```

### Workflow 2 — Recall + reverse logistics (pharma)
```
PHARMA-GR-001: PRODUCED
            → STORED      (WH-ATHENS)
            → IN_TRANSIT  (TRUCK-PHARMA)
            → DISTRIBUTED (DIST-ATH)
            → RECALLED    (Auditor: contamination found)
            → STORED      (WH-QUARANTINE — auditor transfers custody to warehouse)
            → DISPOSED    (warehouse disposes recalled goods)
```

---

## 12. Deployment

A testnet deployment is three coordinated artifacts: the **contract**
(`DeploySepoliaMinimal.s.sol`), a **Goldsky subgraph** indexing it from its deploy block,
and the **frontend** configured with `VITE_CONTRACT_ADDRESS` + `VITE_SUBGRAPH_URL`. Local
Anvil development uses `Deploy.s.sol` (with seeded demo users) instead.

See [deployment.md](deployment.md) for the full local (Anvil) and Sepolia testnet
deployment instructions, including subgraph setup.
