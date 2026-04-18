# TrustChain — Implementation Plan

## Phase 1 — Project Scaffolding

1. Init Foundry project inside `contracts/` (`forge init --no-git`)
2. Configure `contracts/foundry.toml` — solc 0.8.28, optimizer 200 runs
3. Scaffold `ui/` with Vite + Vue 3 + Vuetify 4 + Pinia + ethers.js v6
4. Configure `.devcontainer/devcontainer.json` — Foundry + Node 20
5. Configure `ui/vite.config.js` — `@trustchain-abi` alias pointing to `../contracts/out/TrustChain.sol/TrustChain.json`

---

## Phase 2 — Smart Contract

6. Write `contracts/src/DataTypes.sol` — all enums and structs
7. Write `contracts/src/interfaces/ITrustChain.sol` — function signatures + events
8. Write `contracts/src/TrustChain.sol`:
   - State variables + constructor (seeds registries + transition matrix + deployer as ADMIN)
   - Modifiers + custom errors
   - User domain: `registerUser`, `deactivateUser`, `activateUser`
   - Registry domain: `addProductType`, `addUnit`, getters
   - Batch domain: `createBatch`, view functions
   - Lifecycle domain: `receiveBatch`, `shipBatch`, `distributeBatch`, `recallBatch`, `certifyBatch`, `disposeBatch`
9. Write `contracts/script/Deploy.s.sol`

---

## Phase 3 — Contract Tests

10. Write `contracts/test/TrustChain.t.sol`:
    - User domain: register, deactivate, activate, unauthorized access
    - Batch domain: create, duplicate serial, wrong role
    - Lifecycle: each valid transition, each invalid transition
    - Recall: recall, blocked re-distribution, dispose
    - Certification: certify, unauthorized certify
11. Run `forge test` — all green

---

## Phase 4 — Frontend Core

12. `stores/wallet.js` — MetaMask connect/disconnect, chain switching to Anvil
13. `composables/useUserRole.js` — fetch role on account change
14. `router/index.js` — 4 routes + navigation guard
15. `App.vue` — navbar with role badge + wallet status

---

## Phase 5 — Frontend Views + Components

16. `views/HomeView.vue` — landing + wallet connect
17. `components/common/WalletConnect.vue` + `RoleBadge.vue`
18. `composables/useBatches.js` + `useAdmin.js`
19. `components/batch/BatchCard.vue` + `BatchForm.vue`
20. `views/DashboardView.vue` — role-aware quick actions + batch list
21. `components/batch/BatchTimeline.vue` — event-driven route history
22. `views/BatchDetailView.vue` — full batch data + timeline
23. `views/SearchView.vue` — search by serial or ID
24. `components/admin/UserForm.vue` — register user form inside DashboardView

---

## Phase 6 — Demo Data + Security Audit

25. Deploy to Anvil, register all 6 roles, register 10+ batches
26. Execute 2 complete end-to-end workflows (see design-spec.md §11)
27. Run Slither + Solhint, document findings in PDF

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
