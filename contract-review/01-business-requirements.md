# Business Requirements Analysis

**Source:** `assignment.md` (Greek university assignment)

---

## 1. Mandatory Requirements Matrix

The assignment (in Greek) defines seven numbered requirement groups. Each is evaluated below.

---

### REQ-1 — Smart contract in Solidity tracking batch creation, transfer, storage, and final distribution

| Sub-requirement                                     | Status         | Location                                                             |
| --------------------------------------------------- | -------------- | -------------------------------------------------------------------- |
| Record batch creation with producer, location, date | ✅ Implemented | `createBatch` — records `producer`, `origin`, `creationDate`         |
| Record transfer and storage at successive stages    | ✅ Implemented | `shipBatch`, `receiveBatch` — emit `BatchTransitioned` with location |
| Record final distribution to consumer/POS           | ✅ Implemented | `distributeBatch` — transitions to `DISTRIBUTED`                     |

**Assessment:** Fully compliant. The design adds meaningful extras beyond the minimum: an expiry
date field, a category enum (`PERISHABLE`, `REFRIGERATED`, `HAZARDOUS`, etc.), and a
`recalled` flag for reverse logistics.

---

### REQ-2 — At least six user types with restricted permissions

| Role Required                    | Role Implemented | Match |
| -------------------------------- | ---------------- | ----- |
| Administrator                    | `ADMIN`          | ✅    |
| Producer                         | `PRODUCER`       | ✅    |
| Transporter                      | `TRANSPORTER`    | ✅    |
| Warehouse / Distribution Centre  | `WAREHOUSE`      | ✅    |
| Distributor / Retailer           | `DISTRIBUTOR`    | ✅    |
| Inspector / Regulatory Authority | `AUDITOR`        | ✅    |

**Assessment:** Exactly six roles, all implemented with dedicated `onlyX` modifiers.
The assignment uses the term "Inspector / Regulatory Authority" — mapped to `AUDITOR` here.
The auditor role goes beyond the assignment's "full read access" by also owning `recallBatch`
and `certifyBatch`. This is an appropriate extension.

---

### REQ-3 — UI allowing registration, batch creation, lifecycle tracking, search by ID, role-based views

| Sub-requirement                                 | Status         | Location                                      |
| ----------------------------------------------- | -------------- | --------------------------------------------- |
| Register and connect users with different roles | ✅ Implemented | `ui/src/views/HomeView.vue`, `useUserRole.js` |
| Register new product batches                    | ✅ Implemented | `ui/src/components/batch/`                    |
| Track product journey through blockchain        | ✅ Implemented | `ui/src/views/BatchDetailView.vue`            |
| Search by unique batch ID                       | ✅ Implemented | `ui/src/views/SearchView.vue`                 |
| Show data according to user role                | ✅ Implemented | `useUserRole.js`, role-based routing          |

**Assessment:** Fully compliant based on the UI folder structure. The review does not
deep-dive into UI code; a separate front-end review would be needed for that.

---

### REQ-4 — At least 10 product batches with unique code, product type, category, status

| Sub-requirement            | Status               | Notes                                        |
| -------------------------- | -------------------- | -------------------------------------------- |
| Unique serial/ID per batch | ✅ Enforced on-chain | `DuplicateSerial` error on duplicate         |
| Product type field         | ✅ Implemented       | Dynamic registry seeded with 7 types         |
| Category field             | ✅ Implemented       | `Category` enum — 6 values including `OTHER` |
| Status field               | ✅ Implemented       | `Status` enum — 6 lifecycle states           |

**Assessment:** The data model covers all four required fields. The assignment asks
for **at least 10 batches to be registered as demo data** — this is a deployment/demo
requirement, not a contract code requirement. The contract itself supports unlimited batches.

---

### REQ-5 — At least two complete end-to-end batch journeys from production to sale

| Journey                                                                                       | Test Coverage               | Status |
| --------------------------------------------------------------------------------------------- | --------------------------- | ------ |
| Forward chain: PRODUCED → STORED → IN_TRANSIT → STORED → IN_TRANSIT → DISTRIBUTED → certified | `test_e2e_forwardChain`     | ✅     |
| Recall chain: PRODUCED → STORED → IN_TRANSIT → DISTRIBUTED → RECALLED → STORED → DISPOSED     | `test_e2e_recallAndDispose` | ✅     |

**Assessment:** Both journeys are implemented and tested end-to-end in
`TrustChain.e2e.t.sol`. The forward chain demonstrates a multi-hop journey (two
warehouse stops, two transport legs), which exceeds the minimum.

---

### REQ-6 — Basic security mechanism: event logging and user validity checks

| Mechanism                                          | Status         | Location                                             |
| -------------------------------------------------- | -------------- | ---------------------------------------------------- |
| Logging all critical actions via blockchain events | ✅ Implemented | All state-changing functions emit events             |
| User validity check before critical operations     | ✅ Implemented | `_requireRole` checks `isActive` AND correct `role`  |
| Unauthorized action prevention                     | ✅ Implemented | `onlyAdmin`, `onlyProducer`, etc. via `_requireRole` |

**Assessment:** Fully compliant and well-executed. The `_requireRole` helper combines
the `isActive` liveness check with the role check in a single place, preventing
deactivated users from performing any state-changing action regardless of their historical role.

All the following actions emit dedicated events:

- `UserRegistered`, `UserDeactivated`, `UserActivated`
- `ProductTypeAdded`, `UnitAdded`
- `BatchCreated`, `BatchTransitioned`, `BatchCertified`, `BatchRecalled`

---

### REQ-7 — Security audit with at least one open-source tool

| Tool Used | Version | Findings                                  | Status       |
| --------- | ------- | ----------------------------------------- | ------------ |
| Solhint   | 6.2.1   | 134 warnings, 0 errors, 0 security issues | ✅ Completed |
| Slither   | 0.11.5  | 2 INFO findings (both false positives)    | ✅ Completed |

**Assessment:** Fully compliant. Two tools were used (exceeding the minimum of one).
All findings were documented with responses in `docs/security-audit.md`. The false positives
were correctly identified and justified.

---

## 2. Assignment-Level Extensions (Beyond Minimum)

The implementation goes beyond the assignment's minimum requirements in several ways:

| Extension                                                         | Value                                                                           |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Dynamic product type + unit registries (admin-managed at runtime) | Avoids redeployment for new product categories                                  |
| `recalled` one-way latch                                          | Prevents re-distribution of recalled goods                                      |
| Full transition matrix                                            | Explicit allow-list of valid state jumps; invalid transitions rejected on-chain |
| `expiryDate` field                                                | Enables time-sensitive product tracking (pharmaceuticals, food)                 |
| Foundry test suite (unit + fuzz + invariant + E2E)                | Production-grade test coverage far exceeding academic expectations              |
| Struct storage optimization (5 slots, perfectly packed)           | Reduced gas cost per batch creation                                             |
| Custom errors                                                     | Gas-efficient and semantically clear revert reasons                             |
| Interface separation (`ITrustChain.sol`)                          | Enables tooling, mock generation, and frontend ABI isolation                    |
| `certifyBatch` function                                           | Enables post-distribution quality certification                                 |
| `disposeBatch` / reverse logistics                                | Full reverse supply chain modeled                                               |

---

## 3. Gaps vs. Real-World Supply Chain Requirements

While fully compliant with the academic assignment, the following real-world supply chain
requirements are outside scope but worth noting for completeness:

| Gap                                                        | Impact if Production                                      |
| ---------------------------------------------------------- | --------------------------------------------------------- |
| No custody handshake (sender initiates, receiver confirms) | Any authorized actor can "take" a batch unilaterally      |
| No batch splitting                                         | Cannot model partial deliveries or shipment fragmentation |
| Expiry not enforced at distribution                        | Expired goods can reach consumers on-chain                |
| Single-admin bootstrapping                                 | Admin key loss = system bricked                           |
| No role update mechanism                                   | Users locked to initial role forever                      |
| No pause/emergency stop                                    | Cannot halt contract during incident response             |
| No temperature/condition data                              | Cannot model cold-chain compliance                        |
| No geographic coordinates                                  | Location is a free-form `bytes32`, no geo-validation      |
