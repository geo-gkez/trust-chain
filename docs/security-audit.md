# Security Audit — TrustChain

Tools used: **Solhint 6.2.1** · **Slither 0.11.5**  
Target: `contracts/src/TrustChain.sol`, `contracts/src/ITrustChain.sol`, `contracts/src/DataTypes.sol`

---

## 1. Solhint

### Result summary

| Metric | Count |
|---|---|
| Errors | 0 |
| Warnings | 139 |
| Security vulnerabilities | 0 |

All 139 warnings fall into three categories: missing NatSpec documentation and minor gas micro-optimizations. No security issues were reported. The constructor visibility false positive (S-2) is suppressed via `.solhint.json`.

---

### Finding S-1 — Missing NatSpec documentation

| Field | Value |
|---|---|
| Rule | `use-natspec` |
| Severity | Warning |
| Count | 126 |
| Files | `TrustChain.sol`, `ITrustChain.sol`, `DataTypes.sol` |

**Description:** Solhint flags every public function, event, and state variable that lacks `@notice`, `@param`, or `@author` NatSpec tags.

**Response:** Accepted / intentional. NatSpec is a documentation standard; its absence does not introduce any security risk. Comments were omitted deliberately to keep the codebase concise for academic scope. All function purposes are self-evident from naming and the interface definition in `ITrustChain.sol`.

**Action taken:** None.

---

### Finding S-2 — Constructor visibility false positive

| Field | Value |
|---|---|
| Rule | `func-visibility` |
| Severity | Warning |
| Count | 1 |
| Location | `TrustChain.sol:58` |

**Description:** Solhint reports that the constructor does not explicitly declare visibility.

**Response:** False positive. In Solidity ≥ 0.7.0 constructors do not accept a visibility modifier — the compiler rejects it. The rule is suppressed via `.solhint.json`.

**Action taken:** Updated `.solhint.json` to add the `ignoreConstructors` flag:
```json
{
  "extends": "solhint:recommended",
  "rules": {
    "func-visibility": ["warn", { "ignoreConstructors": true }]
  }
}
```

---

### Finding S-3 — Gas micro-optimizations

| Field | Value |
|---|---|
| Rules | `gas-increment-by-one`, `gas-strict-inequalities` |
| Severity | Warning |
| Count | 8 |
| Locations | `TrustChain.sol:127, 128, 226, 234, 265, 270, 275, 280` |

**Description:**
- `gas-increment-by-one`: suggests `++i` over `i++` in loop counters (~3 gas saved per iteration).
- `gas-strict-inequalities`: suggests `<` over `<=` where semantically equivalent (~3 gas saved).

**Response:** Accepted as-is. These are cosmetic micro-optimizations with negligible real-world impact. The loops in question are bounded by `uint8` (max 255 iterations) and are admin-only setup calls executed rarely. Changing them would not affect correctness, security, or observable gas cost in practice.

**Action taken:** None.

---

### Finding S-4 — Struct packing false positive

| Field | Value |
|---|---|
| Rule | `gas-struct-packing` |
| Severity | Warning |
| Count | 1 |
| Location | `DataTypes.sol:35` |

**Description:** Solhint suggests the `User` struct packing is inefficient.

**Response:** False positive. The `User` struct is already optimally packed:
- Slot 0: `address(20 bytes) + Role/uint8(1) + bool(1) + uint48(6) = 28 bytes`
- Slot 1: `bytes32 name = 32 bytes`

Two slots total, no wasted space. Solhint's static analyzer did not recognize the layout correctly.

**Action taken:** None.

---

## 2. Slither

### Result summary

| Metric | Count |
|---|---|
| Detectors run | 101 |
| High findings | 0 |
| Medium findings | 0 |
| Low / Info findings | 4 |
| Security vulnerabilities | 0 |

Slither produced 3 `timestamp` findings (all false positives) and 1 `dead-code` informational finding. No high or medium severity issues were found.

---

### Finding SL-1 — block.timestamp used in expiry comparison (createBatch)

| Field | Value |
|---|---|
| Detector | `timestamp` |
| Severity | Info |
| Location | `TrustChain.sol:132` — `createBatch` |

**Description:** Slither flags `expiryDate != 0 && expiryDate < block.timestamp` because `block.timestamp` can be manipulated by validators by approximately ±15 seconds.

**Response:** False positive for this use case. Supply chain expiry dates represent days, months, or years in the future. A validator manipulation window of 15 seconds has no practical impact on whether a batch is considered expired.

**Action taken:** None.

---

### Finding SL-2 — Timestamp detector misattributed to address comparison

| Field | Value |
|---|---|
| Detector | `timestamp` |
| Severity | Info |
| Location | `TrustChain.sol:256` — `_registerUser` |

**Description:** Slither reports `users[account].ethAddress != address(0)` as a dangerous timestamp comparison inside `_registerUser`.

**Response:** False positive — this is a zero-address check to detect duplicate registrations and has no relationship to `block.timestamp`. Slither misattributes the finding because `_registerUser` also writes `block.timestamp` to `registeredAt` in the same function body.

**Action taken:** None.

---

### Finding SL-3 — block.timestamp used in expiry check (_transition)

| Field | Value |
|---|---|
| Detector | `timestamp` |
| Severity | Info |
| Location | `TrustChain.sol:294` — `_transition` |

**Description:** Slither flags `b.expiryDate != 0 && b.expiryDate < block.timestamp` in the transition guard added during the chain-of-custody fix.

**Response:** False positive — same rationale as SL-1. Supply chain expiry windows are measured in days or months; ±15 seconds of validator manipulation is irrelevant.

**Action taken:** None.

---

### Finding SL-4 — Dead code: unused internal function overload

| Field | Value |
|---|---|
| Detector | `dead-code` |
| Severity | Informational |
| Location | `TrustChain.sol:303-306` — `_transition(bytes32, Status, bytes32)` |

**Description:** Slither reports that the convenience overload `_transition(bytes32 serialNumber, Status to, bytes32 location)` is defined but never called. All call sites use the primary overload that accepts a `Batch storage` reference directly.

**Response:** Valid finding. The overload was written as a utility but became redundant as call sites were refactored to hold the storage reference for other checks. Removed.

**Action taken:** Overload removed from `TrustChain.sol`.

---

## 3. Security properties verified

Explicit analysis of the three most common smart contract vulnerability classes.

### Reentrancy

**Verdict: Not vulnerable.**

Reentrancy requires an external call that can re-enter the contract before state is committed. `TrustChain` makes no ETH transfers and no external calls of any kind — all functions operate exclusively on internal storage mappings and emit events. There is no code path that calls another contract. Reentrancy is structurally impossible.

### Integer overflow / underflow

**Verdict: Not vulnerable.**

The contract uses Solidity 0.8.28, which has built-in overflow and underflow protection on all arithmetic operations. Any operation that would overflow reverts automatically — no `SafeMath` library is needed. The only arithmetic in the contract is counter increments (`productTypeCount++`, `unitCount++`) and timestamp comparisons, both of which are safe under 0.8.x semantics.

### Access control

**Verdict: Correctly implemented.**

Every state-changing function is protected by a named modifier (`onlyAdmin`, `onlyProducer`, `onlyTransporter`, `onlyWarehouse`, `onlyDistributor`, `onlyAuditor`). All modifiers delegate to `_requireRole(address, Role)`, which checks both that the caller is registered (`ethAddress != address(0)`) and that their role matches AND that `isActive == true`. Deactivated users fail all role checks. There is no function that mutates state without a role check, verified by inspection of every external and public function.

---

## 4. Known design trade-offs (self-identified)




These are not tool findings but design decisions worth acknowledging in the report.

| # | Issue | Severity | Response |
|---|---|---|---|
| D-1 | Expiry date not enforced at lifecycle transitions | Low | **Fixed.** Expiry check added to `_transition()`. Scoped to forward commerce only — transitions to `RECALLED` or `DISPOSED`, and any transition while `status == RECALLED`, are exempt so expired goods can always be removed from the chain. |
| D-2 | O(n) duplicate check in `_addProductType` / `_addUnit` | Low | Accepted — bounded by `uint8` (max 255 entries), admin-only, called only during setup. |
| D-3 | Single admin centralization | Medium | Acknowledged design choice for academic scope. Future work: multisig admin. |
| D-4 | No pause mechanism | Low | Out of scope. Future work: `Pausable` pattern. |

---

## 5. Security mechanisms implemented

| Mechanism | Location | Purpose |
|---|---|---|
| Role-based access control | Every state-changing function | Only authorized roles can call each function |
| `isActive` check | `_requireRole` internal | Deactivated users are fully locked out |
| Chain-of-custody enforcement | `transferCustody`, `shipBatch`, `receiveBatch`, `distributeBatch`, `disposeBatch` | Only the current holder can execute lifecycle transitions; custody is explicitly handed off via `transferCustody` |
| Expiry enforcement | `_transition` internal | Expired batches are blocked from forward commerce; reverse logistics (recall, quarantine, disposal) are exempt |
| `recalled` one-way latch | `recallBatch`, `distributeBatch` | Once recalled, a batch can never be re-distributed |
| Transition matrix enforcement | `_transition` internal | Invalid state jumps are rejected at the contract level |
| Custom errors | All reverts | Gas-efficient, unambiguous revert reasons |
| `SelfDeactivation` guard | `deactivateUser` | Admin cannot deactivate their own account |
| Immutable event log | All critical actions | Tamper-proof on-chain audit trail |
