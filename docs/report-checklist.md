# Report Checklist

Maps each assignment deliverable to the material we have or still need.

---

## PDF Sections

### 1. Problem Description & Importance of Traceability
- [ ] Write 1–2 pages: why supply chain traceability matters (fraud prevention, food safety, pharma recalls)
- [ ] Reference real-world cases (e.g. food contamination recalls, counterfeit medicine)
- [ ] Explain why blockchain is a good fit: immutability, transparency, decentralization

---

### 2. System Architecture
**Already have:**
- State machine diagram (Status transitions table from the plan)
- Struct layouts (`User`, `Batch`) with slot packing explanation
- Domain separation: Admin / Batch / Lifecycle / View

**Still need:**
- [ ] Architecture diagram: MetaMask → Vue 3 UI → ethers.js → Anvil → TrustChain.sol
- [ ] Component diagram: DataTypes.sol / ITrustChain.sol / TrustChain.sol relationship
- [ ] Sequence diagram for at least one lifecycle flow (e.g. createBatch → receiveBatch → shipBatch → distributeBatch)

---

### 3. Roles, Permissions & Operational Flow
**Already have:**
- 6 roles: ADMIN, PRODUCER, TRANSPORTER, WAREHOUSE, DISTRIBUTOR, AUDITOR
- Transition matrix table (who executes each transition)
- `_requireRole` + `isActive` enforcement documented

**Still need:**
- [ ] Role table: role → allowed functions → what they cannot do
- [ ] Flow narrative for each role (what a typical session looks like per role)

---

### 4. Smart Contract Description
**Already have:**
- `DataTypes.sol` — enums + structs with slot layout
- `ITrustChain.sol` — all events and custom errors
- `TrustChain.sol` — full implementation
- Gas report table (forge test --gas-report)
- Gas snapshot baseline (.gas-snapshot)

**Write for report:**
- [ ] Function table: name / modifier / what it does / key validations
- [ ] Custom errors table: error / when thrown / why (no string required — cheaper gas)
- [ ] Events table: event / indexed params / purpose (audit trail)
- [ ] Gas analysis section — use the numbers from --gas-report:
  - `createBatch` most expensive (~116k avg) — 6 cold SSTORE initializations
  - Lifecycle transitions cheaper (~31k–40k) — warm slot updates
  - View functions free when called off-chain
- [ ] Struct packing explanation — why `uint128 + uint48 + uint48 + uint8 + uint8 + uint8 + bool` fits in one 32-byte slot

---

### 5. Security Audit (mandatory)
**Tools required (at least one):**

#### Slither
```bash
cd contracts && slither src/TrustChain.sol
```
- [ ] Run Slither, capture output
- [ ] Document each finding: severity / description / our response (accepted / mitigated / false positive)

#### Solhint
```bash
cd contracts && solhint "src/**/*.sol"
```
- [ ] Run Solhint, capture output
- [ ] Document findings

**Known issues to discuss in report (from our own analysis):**
- [ ] Expiry date not enforced at lifecycle time — batches can be shipped after expiry
- [ ] O(n) duplicate check in `_addProductType` / `_addUnit` — bounded by `uint8` (max 255), acceptable for this use case
- [ ] Single admin centralization — acknowledged design choice for academic scope
- [ ] No pause mechanism — out of scope, worth mentioning as future work

**Security mechanisms already implemented (highlight these):**
- [ ] Role-based access control on every state-changing function
- [ ] `isActive` check blocks deactivated users
- [ ] `recalled` flag is a one-way latch — once set, never cleared
- [ ] Transition matrix enforced for every status change
- [ ] Custom errors instead of require strings (gas + clarity)
- [ ] All critical actions emit events → immutable on-chain audit trail
- [ ] `SelfDeactivation` guard prevents admin from locking themselves out

---

### 6. Test Suite
**Already have — include in report:**
- 84 unit tests — one behavior per test
- 3 fuzz tests — 256 random runs each (uint128 quantity, uint48 expiry, uint8 productTypeId)
- 3 invariant tests — 128,000 calls each (producer immutable, DISPOSED→recalled, recalled≠DISTRIBUTED)
- 2 E2E tests — full lifecycle workflows

**Write for report:**
- [ ] Test strategy section: unit → fuzz → invariant → E2E pyramid
- [ ] Table: test file / count / what it verifies
- [ ] Explain why fuzz tests catch what unit tests cannot (full uint48 space = 281 trillion values)
- [ ] Explain what invariant tests prove (no sequence of random calls can break these properties)
- [ ] Paste the `forge test` summary: 92 tests passed, 0 failed

---

### 7. Demo Data (minimum 10 batches)
**Still need — do this after frontend is ready:**
- [ ] Deploy to Anvil: `forge script script/Deploy.s.sol --broadcast`
- [ ] Register all 6 role accounts via Admin UI
- [ ] Create 10+ batches covering all product types and categories:

| # | Serial | Product Type | Category | Workflow |
|---|--------|-------------|----------|----------|
| 1 | OLIVE-GR-001 | FOOD | PERISHABLE | Forward chain |
| 2 | PHARMA-GR-001 | PHARMA | REFRIGERATED | Recall + dispose |
| 3 | MOTOR-DE-001 | INDUSTRIAL | NON_PERISHABLE | Forward chain |
| 4 | CHIP-TW-001 | ELECTRONICS | FRAGILE | Forward chain |
| 5 | WHEAT-GR-001 | AGRICULTURE | PERISHABLE | Forward chain |
| 6 | ACID-DE-001 | CHEMICAL | HAZARDOUS | Forward chain |
| 7 | SILK-IT-001 | TEXTILE | NON_PERISHABLE | Forward chain |
| 8 | MILK-GR-001 | FOOD | REFRIGERATED | Recall + dispose |
| 9 | VACCINE-GR-001 | PHARMA | REFRIGERATED | Forward chain |
| 10 | COTTON-EG-001 | TEXTILE | NON_PERISHABLE | Forward chain |

- [ ] Execute Workflow 1 (forward chain) end-to-end on at least 2 batches
- [ ] Execute Workflow 2 (recall + dispose) end-to-end on at least 2 batches

---

### 8. UI Screenshots (required for PDF)
Capture after demo data is loaded:
- [ ] Home page / wallet connect screen
- [ ] Dashboard — each role view (at least ADMIN, PRODUCER, AUDITOR)
- [ ] Batch creation form
- [ ] Batch detail view with full timeline (showing all hops)
- [ ] Search by serial number
- [ ] Admin panel — user registration
- [ ] Recall flow (DISTRIBUTED → RECALLED → STORED → DISPOSED)

---

### 9. Conclusions & Future Work
- [ ] What the system achieves: tamper-proof audit trail, role enforcement, recall traceability
- [ ] Limitations: single admin, no expiry enforcement at lifecycle, no off-chain data verification
- [ ] Future work: multisig admin, oracle integrations for real IoT data, Layer 2 for gas reduction, NFT-based batch ownership

---

### 10. Installation & Usage Instructions (separate deliverable)
- [ ] Prerequisites: Node 20, Foundry, MetaMask
- [ ] Start Anvil: `anvil`
- [ ] Deploy contract: `forge script script/Deploy.s.sol --broadcast --rpc-url http://localhost:8545`
- [ ] Start UI: `cd ui && npm install && npm run dev`
- [ ] Import Anvil account #0 into MetaMask (private key from Anvil output)
- [ ] Connect wallet → admin is automatically registered

---

## Status Summary

| Deliverable | Status |
|---|---|
| Smart contract (TrustChain.sol) | Done |
| DataTypes.sol + ITrustChain.sol | Done |
| Test suite (92 tests) | Done |
| Gas report | Done |
| Security audit (Slither + Solhint) | Not started |
| Deploy script | Not started |
| Frontend (Vue 3 + Vuetify) | Not started |
| Demo data (10 batches) | Blocked on frontend |
| UI screenshots | Blocked on frontend |
| PDF report | In progress |
| Installation instructions | Not started |
