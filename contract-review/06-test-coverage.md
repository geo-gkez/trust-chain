# Test Coverage Analysis

---

## 1. Test Suite Overview

| File                         | Type                      | Tests             |
| ---------------------------- | ------------------------- | ----------------- |
| `TrustChain.t.sol`           | Unit tests                | ~40 named tests   |
| `TrustChain.fuzz.t.sol`      | Property / fuzz tests     | 3 fuzz properties |
| `TrustChain.invariant.t.sol` | Stateful invariant tests  | 3 invariants      |
| `TrustChain.e2e.t.sol`       | End-to-end workflow tests | 2 full narratives |
| `TrustChainTestBase.t.sol`   | Shared fixture            | Base class only   |

All test contracts inherit `TrustChainTestBase` which provides a consistent fixture:

- Pre-named addresses: `admin`, `alice`, `bob`, `charlie`, `distributor`, `auditor`
- Helper functions: `_registerAll()`, `_toStored()`, `_toInTransit()`, `_toDistributed()`, `_toRecalledStored()`
- Standard constants: `SERIAL`, `LOC_A`, `LOC_B`, `LOC_C`

---

## 2. Unit Test Coverage by Function

### Admin Domain

| Function         | Happy Path | Access Control               | Edge Cases                         | Coverage  |
| ---------------- | ---------- | ---------------------------- | ---------------------------------- | --------- |
| `registerUser`   | ✅         | ✅ Unauthorized, ZeroAddress | ✅ AlreadyRegistered               | Excellent |
| `deactivateUser` | ✅         | ✅ Unauthorized              | ✅ SelfDeactivation, NotRegistered | Excellent |
| `activateUser`   | ✅         | ✅ Unauthorized              | ✅ NotRegistered                   | Good      |
| `addProductType` | ✅         | ✅ Unauthorized              | ✅ Duplicate                       | Excellent |
| `addUnit`        | ✅         | ✅ Unauthorized              | ✅ Duplicate                       | Excellent |

**Gap:** No test for `activateUser` called on an already-active user (no-op + spurious event,
see F-07).

### Batch Domain

| Function      | Happy Path | Access Control               | Edge Cases                                          | Coverage  |
| ------------- | ---------- | ---------------------------- | --------------------------------------------------- | --------- |
| `createBatch` | ✅         | ✅ Unauthorized, deactivated | ✅ InvalidProductType, InvalidUnit, DuplicateSerial | Excellent |

**Gaps:**

- No test for `createBatch` with `serialNumber == bytes32(0)` → `InvalidSerialNumber`.
- No test for `createBatch` with `quantity == 0` → `InvalidQuantity`.
- No test for `createBatch` with `origin == bytes32(0)` → `InvalidOrigin`.

These validations exist in the contract but are not covered by a dedicated test. All three
are simple boundary tests that should be added.

### Lifecycle Domain

| Function          | Happy Path       | Access Control | Transition Errors                          | Coverage |
| ----------------- | ---------------- | -------------- | ------------------------------------------ | -------- |
| `receiveBatch`    | ✅ (via helpers) | Partial        | ✅ (via InvalidTransition)                 | Good     |
| `shipBatch`       | ✅ (via helpers) | Partial        | ✅                                         | Good     |
| `distributeBatch` | ✅               | Partial        | ✅ CannotDistributeRecalled                | Good     |
| `recallBatch`     | ✅               | Partial        | —                                          | Good     |
| `certifyBatch`    | ✅               | ✅             | ✅ AlreadyCertified, CannotCertifyInStatus | Good     |
| `disposeBatch`    | ✅               | Partial        | ✅ BatchNotRecalled                        | Good     |

**Gaps:**

- No test verifying that lifecycle functions fail with `Unauthorized` for the wrong role
  (e.g., a PRODUCER calling `shipBatch`).
- No test verifying that `BatchNotFound` fires on an unknown serialNumber for lifecycle
  functions.

---

## 3. Fuzz Test Coverage

### `testFuzz_createBatch_storesQuantityExactly`

Tests the full `uint128` range for quantity (0 excluded by `vm.assume`). Catches any
truncation or packing bug in slot 0 of the Batch struct. Well-designed.

### `testFuzz_createBatch_expiryBoundary`

Tests the full `uint48` space for expiry date against `block.timestamp`. The test correctly
separates the two valid cases (`expiryDate == 0` and `expiryDate >= timestamp`) from the
invalid case (`expiryDate < timestamp && expiryDate != 0`).

**Minor note:** The test comment explains a subtle `vm.prank` ordering issue — reading
`productTypeCount()` after `vm.prank` would consume the prank. This is a well-spotted
Foundry gotcha and the comment is valuable.

### `testFuzz_createBatch_productTypeIdBoundary`

Tests boundary behavior at `productTypeId = productTypeCount - 1` (valid) and
`productTypeId = productTypeCount` (invalid). Covers the entire `uint8` range.

**Suggested additions:**

- `testFuzz_unitIdBoundary` — mirror of the productType test for `unitId`.
- `testFuzz_transition_invalidStatus` — verify that any `(from, to)` pair not in the matrix
  reverts with `InvalidTransition`.

---

## 4. Invariant Test Coverage

### `invariant_producerIsImmutable`

Checks that `batch.producer` stays equal to `alice` after any sequence of random calls.
Well-designed and essential.

**Weakness:** Only one batch (`SERIAL`) is tracked. If additional batches are created during
invariant exploration, their producers are not verified. Since `createBatch` is in the target
contract's function list, Foundry's fuzzer will occasionally call it with random serial
numbers — but those batches' producers are not checked.

### `invariant_disposedImpliesRecalled`

Checks `status == DISPOSED → recalled == true`. Essential safety property.

### `invariant_recalledBatchNotDistributed`

Checks `recalled == true → status != DISTRIBUTED`. Prevents re-distribution after recall.

**Missing invariant:**

```solidity
// recalled == true → certified == false
function invariant_recalledBatchNotCertified() public view {
    Batch memory b = tc.getBatch(SERIAL);
    if (b.recalled) {
        assertFalse(b.certified);
    }
}
```

The contract's `certifyBatch` correctly blocks certification of RECALLED/DISPOSED batches,
but this invariant is not tested under stateful fuzzing.

---

## 5. End-to-End Test Coverage

### `test_e2e_forwardChain`

Covers the normal supply chain lifecycle:
`PRODUCED → STORED → IN_TRANSIT → STORED → IN_TRANSIT → DISTRIBUTED → certified`

Asserts `status` and `currentHolder` at every hop. Asserts `certified == true` and
`recalled == false` at the end.

**Quality:** Excellent — tests the multi-hop model that distinguishes this implementation
from a naive two-step contract.

### `test_e2e_recallAndDispose`

Covers the full recall and disposal lifecycle:
`PRODUCED → STORED → IN_TRANSIT → DISTRIBUTED → RECALLED → STORED → [attempt DISTRIBUTED fails] → DISPOSED`

Importantly, the test:

1. Verifies `recalled == true` persists through RECALLED → STORED transition.
2. Verifies `CannotDistributeRecalled` on re-distribution attempt.
3. Verifies `recalled == true` and `certified == false` on final DISPOSED batch.

**Quality:** Excellent.

**Missing E2E scenario:** A batch that skips the warehouse and goes directly
`PRODUCED → IN_TRANSIT → DISTRIBUTED` is not tested in the E2E suite (though the unit
tests do cover the direct-to-transit path).

---

## 6. Test Infrastructure Quality

### Fixture Helpers

The `_toStored()`, `_toInTransit()`, `_toDistributed()`, `_toRecalledStored()` helpers in
`TrustChainTestBase` are well-designed. They compose on each other (each calls the previous),
which means any test can set up a specific state with a single call:

```solidity
function test_disposeBatch_happyPath() public {
    _toRecalledStored();          // one line to reach STORED+recalled
    vm.prank(charlie);
    tc.disposeBatch(SERIAL, LOC_A);
    assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.DISPOSED));
}
```

This is an excellent pattern for readable, maintainable tests.

### Address Naming

`makeAddr("Alice")` is used instead of hardcoded addresses. This is best practice in Foundry —
it produces deterministic, labelled addresses that appear by name in traces.

### Gas Snapshot

The `.gas-snapshot` file records per-test gas consumption. This is valuable for detecting
gas regressions across refactors.

---

## 7. Coverage Gaps Summary

| Gap                                             | Risk | Suggested Test                                        |
| ----------------------------------------------- | ---- | ----------------------------------------------------- |
| `createBatch` with `serialNumber == bytes32(0)` | Low  | `test_createBatch_revertsWhenInvalidSerial`           |
| `createBatch` with `quantity == 0`              | Low  | `test_createBatch_revertsWhenZeroQuantity`            |
| `createBatch` with `origin == bytes32(0)`       | Low  | `test_createBatch_revertsWhenInvalidOrigin`           |
| `activateUser` on already-active user           | Info | `test_activateUser_idempotent`                        |
| Lifecycle functions called by wrong role        | Low  | `test_shipBatch_revertsWhenCallerNotTransporter` etc. |
| `getBatch` on non-existent serial               | Low  | `test_getBatch_returnsEmptyForUnknownSerial`          |
| Invariant: recalled → not certified             | Low  | `invariant_recalledBatchNotCertified`                 |
| Fuzz: unitId boundary                           | Low  | `testFuzz_createBatch_unitIdBoundary`                 |
| E2E: direct PRODUCED → IN_TRANSIT               | Info | `test_e2e_directShipFromProducer`                     |
