# TrustChain — Implementation Plan

## Phase 1 — Project Scaffolding

1. Configure `.devcontainer/devcontainer.json` — Foundry + Node 20
2. Init Foundry project inside `contracts/` (`forge init --no-git`)
3. Configure `contracts/foundry.toml` — solc 0.8.28, optimizer 200 runs
4. Scaffold `ui/` with Vite + Vue 3 + Vuetify 4 + Pinia + ethers.js v6
5. Configure `ui/vite.config.js` — `@trustchain-abi` alias pointing to `../contracts/out/TrustChain.sol/TrustChain.json`

---

## Phase 2 — Smart Contract (TDD — tests first per domain)

**Approach:** Write DataTypes + interface + contract skeleton first (compilation target),
then for each domain: write failing tests → implement → green.

6. Write `contracts/src/DataTypes.sol` — all enums and structs
7. Write `contracts/src/interfaces/ITrustChain.sol` — function signatures + events
8. Write `contracts/src/TrustChain.sol` skeleton:
   - State variables + constructor (seeds registries + transition matrix + deployer as ADMIN)
   - Custom errors
   - Modifiers + `_requireRole` internal
   - Empty function stubs (revert or no-op) — enough to compile

9. **User domain (TDD cycle):**
   a. Write tests: register, deactivate, activate, unauthorized access, zero address, duplicate
   b. Implement: `registerUser`, `deactivateUser`, `activateUser`, `getUser`
   c. `forge test` — green

10. **Registry domain (TDD cycle):**
    a. Write tests: addProductType, addUnit, duplicate name, getters
    b. Implement: `addProductType`, `addUnit`, `getProductTypes`, `getUnits`
    c. `forge test` — green

11. **Batch domain (TDD cycle):**
    a. Write tests: createBatch, duplicate serial, wrong role, getBatch, getBatchBySerial
    b. Implement: `createBatch`, `getBatch`, `getBatchBySerial`
    c. `forge test` — green

12. **Lifecycle domain (TDD cycle):**
    a. Write tests: each valid transition, each invalid transition, role checks
    b. Implement: `receiveBatch`, `shipBatch`, `distributeBatch`
    c. `forge test` — green

13. **Recall + certification domain (TDD cycle):**
    a. Write tests: recall, blocked re-distribution, dispose, certify, unauthorized certify
    b. Implement: `recallBatch`, `certifyBatch`, `disposeBatch`
    c. `forge test` — all green

14. Write `contracts/script/Deploy.s.sol`

---

## Phase 3 — Frontend Core

15. `stores/wallet.js` — MetaMask connect/disconnect, chain switching to Anvil
16. `composables/useUserRole.js` — fetch role on account change
17. `router/index.js` — 4 routes + navigation guard
18. `App.vue` — navbar with role badge + wallet status

---

## Phase 4 — Frontend Views + Components

19. `views/HomeView.vue` — landing + wallet connect
20. `components/common/WalletConnect.vue` + `RoleBadge.vue`
21. `composables/useBatches.js` + `useAdmin.js`
22. `components/batch/BatchCard.vue` + `BatchForm.vue`
23. `views/DashboardView.vue` — role-aware quick actions + batch list
24. `components/batch/BatchTimeline.vue` — event-driven route history
25. `views/BatchDetailView.vue` — full batch data + timeline
26. `views/SearchView.vue` — search by serial or ID
27. `components/admin/UserForm.vue` — register user form inside DashboardView

---

## Phase 5 — Demo Data + Security Audit

28. Deploy to Anvil, register all 6 roles, register 10+ batches
29. Execute 2 complete end-to-end workflows (see design-spec.md §11)
30. Run Slither + Solhint, document findings in PDF

---

## Verification

```bash
# Contracts
cd contracts && forge build           # zero warnings
cd contracts && forge test -vv        # all tests pass
cd contracts && forge fmt --check     # formatting clean

# Security audit
cd contracts && slither src/TrustChain.sol
cd contracts && solhint "src/**/*.sol"

# Frontend
cd ui && npm run dev                  # connects to Anvil on localhost:8545
```

Manual demo checklist:
- Connect MetaMask to Anvil (chainId 31337)
- Register one user per role (6 total)
- Create 10+ batches with varied product types and categories
- Complete Workflow 1 (olive oil — full forward chain)
- Complete Workflow 2 (pharma — recall + reverse logistics)
- Verify `BatchDetailView` shows full route timeline for both workflows
- Verify `SearchView` finds batches by serial and by ID
- Verify AUDITOR sees all batches; PRODUCER sees only their own
