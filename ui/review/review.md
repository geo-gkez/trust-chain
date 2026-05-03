# UI Code Review — TrustChain Frontend

> Reviewed by: Senior Front-End / Blockchain Engineer  
> Initial review: 2026-04-30 · **Updated: 2026-04-30 (round 3)**  
> Stack: Vue 3 · Vuetify 4 · Pinia · Vue Router 4 · Ethers.js v6 · Vite 8

---

## Round 2 — What Changed

| #                                     | Issue                             | Was                                              | Now |
| ------------------------------------- | --------------------------------- | ------------------------------------------------ | --- |
| Dashboard Manage Users                | Manual lookup field + detail card | ✅ Replaced with `v-data-table` + inline actions |
| Dashboard loading states              | `v-progress-circular`             | ✅ `v-skeleton-loader` (better UX)               |
| `manageBusy` tracking                 | Boolean flag (all rows blocked)   | ✅ Address string (per-row loading)              |
| `certifyError` / `lookupError`        | Local `ref` + `v-alert`           | ✅ Removed — errors handled by toast             |
| `parseContractError` in DashboardView | Imported and used inline          | ✅ Removed — composables handle it               |
| `role` ref in DashboardView           | Destructured but unused           | ✅ Removed — only `roleLabel` used               |
| `TransitionForm` error display        | Local `txError` ref + `v-alert`   | ✅ Removed — now uses `toast.show()`             |
| `refresh()` in DashboardView          | Did not reload users              | ✅ Now also calls `loadAllUsers()`               |

Good iteration. The Admin User Management section went from a manual lookup pattern to a proper searchable, sortable data table — a significant UX and code quality improvement.

---

## Round 3 — What Changed

| #            | Issue                                  | Was                                           | Now                                                            |
| ------------ | -------------------------------------- | --------------------------------------------- | -------------------------------------------------------------- |
| 2a           | `ROLES`/`ROLE_COLORS` duplicated       | Declared locally in `DashboardView`           | ✅ Imported from `useUserRole.js`                              |
| 2b (partial) | `shortAddr` / `AddressChip` underused  | Inline in `BatchTimeline` + `BatchDetailView` | ✅ `AddressChip` used; `BatchCard` still has local `shortAddr` |
| 2c           | `formatDate` duplicated                | Defined in 3 components                       | ✅ Extracted to `src/utils/format.js`                          |
| 4            | Ethereum listener memory leak          | Listeners stacked on every `connect()`        | ✅ `listenersRegistered` flag prevents re-registration         |
| 5            | `TransitionForm` bypasses `useBatches` | Called `wallet.contract[action]()` directly   | ✅ Delegates to `useBatches[action](serial, location)`         |
| 6            | Unused `useUserRole` import in router  | Dead import at top of `router/index.js`       | ✅ Removed                                                     |
| 9            | `package.json` name                    | `"ui"`                                        | ✅ `"trustchain-ui"`                                           |

Six issues resolved. `TransitionForm` is now a clean, thin delegation component. `formatDate` centralisation is complete. The only address-display duplication still outstanding is `shortAddr` in `BatchCard.vue` and inconsistent inline truncation in `DashboardView`'s user table (10+4 chars instead of 6+4).

---

## Overall Verdict

**Solid and improving** — six more issues resolved in round 3. Core patterns (Composition API, Pinia, composable delegation) are all correct. Remaining pain points are structural (god component, utility placement) and convenience (caching, form validation, tests).

---

## ✅ Strengths (maintained through round 3)

### Architecture & Structure

- **Sensible folder layout** (`components/`, `composables/`, `stores/`, `views/`, `plugins/`, `router/`) — concerns are clearly separated from the start.
- **Lazy-loaded routes** — all four routes use `() => import(...)`, which keeps the initial bundle small.
- **Pinia stores** are correctly scoped: `wallet` for connection state, `toast` for global notifications. Nothing more is stuffed in; both stores stay lean.
- **Vuetify alias** `@trustchain-abi` in `vite.config.js` decouples the UI from the contracts folder path — smart.
- **`markRaw`** is correctly applied to the Ethers `BrowserProvider` and `Contract` instances, preventing Vue from wrapping heavy third-party objects in reactive proxies.
- **`.env.example`** is present and well-commented, guiding new contributors through the setup.

### Vue Patterns

- `<script setup>` is used consistently across all components and views — no Options API mixing.
- Composables follow the standard `use*` naming and return reactive refs, keeping components thin.
- `storeToRefs` is used correctly in `useUserRole.js` to extract reactive store properties without losing reactivity.
- Form validation uses Vuetify's native `v-form` + `rules` array — no third-party form library needed.
- `onMounted` + `Promise.all` is used in several views to parallelise independent RPC calls — good instinct.

### Blockchain / Ethers

- Chain-switch / chain-add flow (`wallet_switchEthereumChain` → `4902` fallback to `wallet_addEthereumChain`) is implemented correctly.
- `parseContractError` provides a single, centralised place to map revert reasons to user-facing strings — excellent.
- `bytes32ToString` / `stringToBytes32` wrappers correctly use `ethers.decodeBytes32String` / `ethers.encodeBytes32String`.
- `decodeBatch` normalises raw contract structs into plain JS objects — views never touch raw `BigInt` or hex strings.
- Router guard verifies on-chain registration (not just wallet connection) before granting access — this is the right approach for a permission-gated DApp.

---

## ❌ Remaining Issues

> Items marked ✅ FIXED were addressed in rounds 2 or 3.

---

### ~~Dashboard Manage Users UX~~ — ✅ FIXED

Replaced with `v-data-table` with search, sortable columns, and per-row activate/deactivate with address-based loading state. The old manual lookup + card pattern is gone. Well done.

---

### ~~`TransitionForm` local error display~~ — ✅ FIXED

The local `txError` ref and `v-alert` were removed. `TransitionForm` now delegates entirely to `useBatches` and uses the composable's `loading` ref and per-action `TRANSITION_MESSAGES`.

---

### 1. `DashboardView.vue` is a God Component — **High Priority**

**File:** `src/views/DashboardView.vue` (~450 lines after cleanup, still covers 6 roles)

Each role's expansion panel should become its own sub-component. The script block still mixes state for all roles.

**Recommendation:** Extract each panel into a dedicated sub-component:

```
src/components/dashboard/
  AdminPanel.vue
  ProducerPanel.vue
  WarehousePanel.vue
  TransporterPanel.vue
  DistributorPanel.vue
  AuditorPanel.vue
```

`DashboardView.vue` then becomes a thin orchestrator:

```vue
<v-expansion-panel v-if="isAdmin" value="admin">
  <AdminPanel @refresh="refresh" />
</v-expansion-panel>
```

---

### 2. Code Duplication — **High Priority**

#### ~~2a. `ROLES` / `ROLE_COLORS` maps defined twice~~ — ✅ FIXED

`DashboardView.vue` now imports `ROLES` and `ROLE_COLORS` directly from `useUserRole.js`. No local re-declaration.

#### 2b. `shortAddr` still in `BatchCard.vue`; inconsistent truncation in Dashboard — **High Priority**

`BatchTimeline.vue` and `BatchDetailView.vue` now use `<AddressChip>` correctly. However `BatchCard.vue` still defines a local `shortAddr()` function. Additionally, `DashboardView.vue`'s user table renders addresses inline with a **different truncation length** (10 prefix chars instead of the 6 used by `AddressChip`):

```html
{{ item.ethAddress.slice(0, 10) }}…{{ item.ethAddress.slice(-4) }}
```

**Fix:** Replace both with `<AddressChip :address="item.ethAddress" />`.

#### ~~2c. `formatDate` duplicated in three files~~ — ✅ FIXED

`src/utils/format.js` was created with a single canonical `formatDate(d, includeTime)`. All three components now import from there. Done.

---

### 3. Utility Functions Exported from a Domain Composable — **Medium Priority**

**File:** `src/composables/useBatches.js`

`parseContractError`, `bytes32ToString`, `stringToBytes32`, `decodeBatch`, `STATUS_LABELS`, `STATUS_COLORS`, `CATEGORY_LABELS` are all exported from a composable that also has stateful logic. `useAdmin.js` imports utilities from `useBatches.js`, creating a cross-domain dependency.

**Fix:** Move pure utilities to a dedicated module:

```
src/utils/
  contract.js    ← parseContractError
  bytes32.js     ← bytes32ToString, stringToBytes32
  constants.js   ← STATUS_LABELS, STATUS_COLORS, CATEGORY_LABELS, ROLES, ROLE_COLORS
```

This also eliminates the awkward import `from '@/composables/useBatches'` in `useAdmin.js` and `DashboardView.vue`.

---

### ~~4. Memory Leak: Ethereum Event Listeners Accumulate~~ — ✅ FIXED

`wallet.js` now uses a module-level `listenersRegistered` flag. The `window.ethereum.on(...)` block is skipped on all subsequent `connect()` calls. Listener accumulation is eliminated.

---

### ~~5. `TransitionForm.vue` Still Bypasses `useBatches`~~ — ✅ FIXED

`TransitionForm.vue` now imports `useBatches()` and delegates via `batches[props.action](serial, location)`. It uses the composable's `loading` ref and proper `TRANSITION_MESSAGES`. The component has no direct `wallet` dependency.

---

### ~~6. Unused Import in Router~~ — ✅ FIXED

The dead `import { useUserRole }` line has been removed from `router/index.js`.

---

### 7. Redundant RPC Calls for `productTypes` and `units` — **Low Priority**

`productTypes` and `units` are fetched independently in:

- `DashboardView.vue` (`onMounted`)
- `SearchView.vue` (`onMounted`)
- `BatchDetailView.vue` (`onMounted`)
- `BatchForm.vue` (`onMounted`)

Each navigation triggers fresh RPC calls. These lists are admin-managed and change rarely.

**Fix:** Cache them in a Pinia store or a singleton composable using `shallowRef` + a `loaded` flag:

```js
// stores/registry.js
export const useRegistryStore = defineStore("registry", () => {
  const productTypes = ref([]);
  const units = ref([]);
  let loaded = false;

  async function load(contract) {
    if (loaded) return;
    [productTypes.value, units.value] = await Promise.all([
      contract.getProductTypes(),
      contract.getUnits(),
    ]);
    loaded = true;
  }
  return { productTypes, units, load };
});
```

---

### 8. Missing Input Validation in `TransitionForm.vue` — **Low Priority**

The `execute()` function only checks `if (!serial.value || !location.value) return` but does not validate that the serial is a valid format or that the location is non-empty after trimming. `BatchForm.vue` uses Vuetify rules properly; `TransitionForm.vue` should do the same.

---

### ~~9. `package.json` Name~~ — ✅ FIXED

Updated to `"trustchain-ui"`.

---

### 10. No Unit or Component Tests — **Notable Absence**

No test files under `ui/`. Vitest + `@vue/test-utils` with a mocked `ethers.Contract` and `window.ethereum` would cover the most valuable paths.

---

## Summary Table

| #   | Issue                                                            | Severity | Status   |
| --- | ---------------------------------------------------------------- | -------- | -------- |
| —   | Dashboard `v-data-table` + skeleton loaders                      | High     | ✅ FIXED |
| —   | `TransitionForm` local `txError`                                 | Medium   | ✅ FIXED |
| —   | `ROLES`/`ROLE_COLORS` duplicated                                 | High     | ✅ FIXED |
| —   | `formatDate` duplicated                                          | Medium   | ✅ FIXED |
| —   | Ethereum listener memory leak                                    | Medium   | ✅ FIXED |
| —   | `TransitionForm` bypasses `useBatches`                           | Medium   | ✅ FIXED |
| —   | Unused import in router                                          | Low      | ✅ FIXED |
| —   | `package.json` name too generic                                  | Minor    | ✅ FIXED |
| 1   | `DashboardView` is a god component                               | High     | Open     |
| 2b  | `shortAddr` in `BatchCard`; inconsistent truncation in Dashboard | High     | Open     |
| 3   | Utilities mixed into domain composable                           | Medium   | Open     |
| 7   | `productTypes`/`units` fetched on every mount                    | Low      | Open     |
| 8   | Missing form validation in `TransitionForm`                      | Low      | Open     |
| 10  | No unit/component tests                                          | Notable  | Open     |
