# Recommendations

Findings are ordered by implementation priority. Each recommendation includes a code
sketch where applicable.

---

## Priority 1 — Medium Severity (Address Before Any Public Deployment)

---

### REC-01 — Add missing recall transition paths (F-04)

Add `STORED → RECALLED` and `IN_TRANSIT → RECALLED` (and optionally `PRODUCED → RECALLED`)
to the transition matrix. This allows auditors to recall unsafe batches at any lifecycle stage.

```solidity
// In constructor, add:
allowedTransitions[Status.PRODUCED][Status.RECALLED]    = true;
allowedTransitions[Status.STORED][Status.RECALLED]       = true;
allowedTransitions[Status.IN_TRANSIT][Status.RECALLED]   = true;
```

No changes needed to `recallBatch` — the transition guard already delegates to `_transition`.

**Test to add:**

```solidity
function test_recallBatch_fromStoredState() public {
    _toStored();
    vm.prank(auditor);
    tc.recallBatch(SERIAL, LOC_A);
    assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.RECALLED));
    assertTrue(tc.getBatch(SERIAL).recalled);
}
```

---

### REC-02 — Add custody check before lifecycle transitions (F-05)

Prevent any actor from transitioning a batch they do not hold.

**Lightweight approach** — add a guard in `_transition`:

```solidity
function _transition(Batch storage b, bytes32 serialNumber, Status to, bytes32 location) internal {
    // Custody check: caller must be the current holder
    if (b.currentHolder != msg.sender) revert NotCurrentHolder();

    Status from = b.status;
    if (!allowedTransitions[from][to]) revert InvalidTransition(from, to);
    b.status = to;
    b.currentHolder = msg.sender;
    emit BatchTransitioned(serialNumber, from, to, location, msg.sender, uint48(block.timestamp));
}
```

Add `error NotCurrentHolder();` to `ITrustChain.sol`.

**Note:** This change has implications for the first transition. When a TRANSPORTER picks up
directly from the producer (`PRODUCED → IN_TRANSIT`), the currentHolder is the producer
(address), and the transporter calling `shipBatch` would fail the custody check. The handoff
model would need to define whether the producer must call `initTransfer` or the transporter
can claim custody. The simplest fix: exclude `PRODUCED → IN_TRANSIT` from the custody check,
or add an explicit `handoffBatch(address nextHolder)` function for the producer.

---

### REC-03 — Accept `initialAdmin` as a constructor parameter (F-01)

Allow the deployer to designate a different address (e.g., a Gnosis Safe multisig) as admin
at deployment time, without the deployer EOA needing to be the admin.

```solidity
constructor(address initialAdmin) {
    if (initialAdmin == address(0)) revert ZeroAddress();
    _registerUser(initialAdmin, "Admin", Role.ADMIN);
    // ... rest of constructor
}
```

Update `Deploy.s.sol`:

```solidity
address safe = vm.envAddress("ADMIN_SAFE");
tc = new TrustChain(safe);
```

---

### REC-04 — Add `updateUserRole` function (F-02)

Once an address is registered its role is immutable. An employee who changes roles has no
upgrade path without retiring their address, breaking on-chain audit trail continuity.

```solidity
// In ITrustChain.sol:
event UserRoleUpdated(address indexed user, Role oldRole, Role newRole);
error RoleUnchanged();

// In TrustChain.sol:
function updateUserRole(address user, Role newRole) external onlyAdmin {
    User storage u = _requireRegistered(user);
    if (u.role == newRole) revert RoleUnchanged();
    Role oldRole = u.role;
    u.role = newRole;
    emit UserRoleUpdated(user, oldRole, newRole);
}
```

---

## Priority 2 — Low Severity (Fix Before Production Hardening)

---

### REC-05 — Fix `recalled` flag ordering in `recallBatch` (F-03)

Set the flag before calling `_transition` to satisfy the checks-effects-interactions principle.

```solidity
function recallBatch(bytes32 serialNumber, bytes32 location) external onlyAuditor {
    Batch storage b = _requireBatch(serialNumber);
    b.recalled = true;                                      // state write first
    _transition(b, serialNumber, Status.RECALLED, location);
    emit BatchRecalled(serialNumber, msg.sender);
}
```

---

### REC-06 — Enforce expiry date at distribution time (F-06)

```solidity
function distributeBatch(bytes32 serialNumber, bytes32 location) external onlyDistributor {
    Batch storage b = _requireBatch(serialNumber);
    if (b.recalled) revert CannotDistributeRecalled();
    if (b.expiryDate != 0 && b.expiryDate < block.timestamp) revert BatchExpired();
    _transition(b, serialNumber, Status.DISTRIBUTED, location);
}
```

Add `error BatchExpired();` to `ITrustChain.sol`.

---

### REC-07 — Restrict `certifyBatch` to `DISTRIBUTED` state only (F-13)

```solidity
function certifyBatch(bytes32 serialNumber) external onlyAuditor {
    Batch storage b = _requireBatch(serialNumber);
    if (b.status != Status.DISTRIBUTED) revert CannotCertifyInStatus(b.status);
    if (b.certified) revert AlreadyCertified();
    b.certified = true;
    emit BatchCertified(serialNumber, msg.sender);
}
```

---

### REC-08 — Remove misleading `STORED → DISPOSED` matrix entry (F-12)

```solidity
// Remove this line from the constructor:
allowedTransitions[Status.STORED][Status.DISPOSED] = true;
```

The `disposeBatch` function already guards `if (!b.recalled) revert BatchNotRecalled()`.
The matrix entry creates a false impression that any STORED batch can be disposed.
The function guard is the correct enforcement point; the matrix should not list this transition.

**Note:** After this change, `disposeBatch` would fail at the matrix check
(`_transition` → `InvalidTransition(STORED, DISPOSED)`) unless the guard fires first.
With `if (!b.recalled) revert BatchNotRecalled()` executing before `_transition`, a
non-recalled STORED batch would still correctly revert with `BatchNotRecalled` (not
`InvalidTransition`). For a recalled STORED batch, the matrix transition must be present.

**Revised recommendation:** Keep `STORED → DISPOSED` in the matrix (it IS the valid path for
recalled goods), but add a comment in the code explicitly stating the constraint:

```solidity
// STORED → DISPOSED is valid ONLY when recalled == true.
// The application-level guard in disposeBatch enforces this; the matrix alone does not.
allowedTransitions[Status.STORED][Status.DISPOSED] = true;
```

---

### REC-09 — Validate `location != bytes32(0)` in lifecycle functions (F-15)

`createBatch` rejects `origin == bytes32(0)` but every lifecycle function accepts a zero
`location` silently, allowing `BatchTransitioned` events with meaningless zero-location data.

```solidity
// In ITrustChain.sol:
error InvalidLocation();

// In TrustChain.sol — add to _transition (overload with Batch storage ref):
function _transition(Batch storage b, bytes32 serialNumber, Status to, bytes32 location) internal {
    if (location == bytes32(0)) revert InvalidLocation();
    Status from = b.status;
    if (!allowedTransitions[from][to]) revert InvalidTransition(from, to);
    b.status = to;
    b.currentHolder = msg.sender;
    emit BatchTransitioned(serialNumber, from, to, location, msg.sender, uint48(block.timestamp));
}
```

Adding it in `_transition` covers all five lifecycle functions in one place.

---

### REC-10 — Make `getBatch` / `getUser` revert for non-existent keys (F-16)

Currently both view functions return a zeroed struct for unknown keys. External callers have
no clean way to detect "not found" without knowing to check `serialNumber == bytes32(0)`.

```solidity
function getBatch(bytes32 serialNumber) external view returns (Batch memory) {
    return _requireBatch(serialNumber);   // reuses existing guard
}

function getUser(address user) external view returns (User memory) {
    return _requireRegistered(user);      // reuses existing guard
}
```

This reuses the already-existing `_requireBatch` and `_requireRegistered` helpers at zero
additional code cost.

---

## Priority 3 — Info / Quality Improvements

---

### REC-11 — Add `BatchDisposed` event for consistency (F-08)

```solidity
// In ITrustChain.sol:
event BatchDisposed(bytes32 indexed serialNumber, address indexed by);

// In TrustChain.sol:
function disposeBatch(bytes32 serialNumber, bytes32 location) external onlyWarehouse {
    Batch storage b = _requireBatch(serialNumber);
    if (!b.recalled) revert BatchNotRecalled();
    _transition(b, serialNumber, Status.DISPOSED, location);
    emit BatchDisposed(serialNumber, msg.sender);   // add this
}
```

---

### REC-12 — Add idempotency guard to `activateUser` (F-07)

```solidity
function activateUser(address user) external onlyAdmin {
    User storage u = _requireRegistered(user);
    if (u.isActive) revert AlreadyActive();         // add this
    u.isActive = true;
    emit UserActivated(user);
}
```

Add `error AlreadyActive();` to `ITrustChain.sol`.

---

### REC-13 — Add `uint8` overflow guard with custom error (F-10)

```solidity
error MaxProductTypesReached();
error MaxUnitsReached();

function _addProductType(string memory name) internal {
    if (productTypeCount == type(uint8).max) revert MaxProductTypesReached();
    // ... rest of function
}
```

---

### REC-14 — Add missing invariant test for recalled → not certified

```solidity
// In TrustChain.invariant.t.sol:
function invariant_recalledBatchNotCertified() public view {
    Batch memory b = tc.getBatch(SERIAL);
    if (b.recalled) {
        assertFalse(b.certified);
    }
}
```

---

### REC-15 — Add missing unit tests for createBatch validation paths

```solidity
function test_createBatch_revertsWhenInvalidSerial() public {
    tc.registerUser(alice, "Alice", Role.PRODUCER);
    vm.prank(alice);
    vm.expectRevert(ITrustChain.InvalidSerialNumber.selector);
    tc.createBatch(bytes32(0), 0, Category.PERISHABLE, 0, 100, "GR-PEL", 0);
}

function test_createBatch_revertsWhenZeroQuantity() public {
    tc.registerUser(alice, "Alice", Role.PRODUCER);
    vm.prank(alice);
    vm.expectRevert(ITrustChain.InvalidQuantity.selector);
    tc.createBatch("BATCH-001", 0, Category.PERISHABLE, 0, 0, "GR-PEL", 0);
}

function test_createBatch_revertsWhenInvalidOrigin() public {
    tc.registerUser(alice, "Alice", Role.PRODUCER);
    vm.prank(alice);
    vm.expectRevert(ITrustChain.InvalidOrigin.selector);
    tc.createBatch("BATCH-001", 0, Category.PERISHABLE, 0, 100, bytes32(0), 0);
}
```

---

### REC-16 — Document or add admin override for erroneous recalls (F-17)

A recall issued against the wrong serial number is permanent — no function can clear
`recalled = true`. Consider an admin-only escape hatch restricted to non-distributed batches:

```solidity
// In ITrustChain.sol:
event BatchRecallReverted(bytes32 indexed serialNumber, address indexed by);
error CannotUndoRecall();

// In TrustChain.sol:
function unrecallBatch(bytes32 serialNumber) external onlyAdmin {
    Batch storage b = _requireBatch(serialNumber);
    // Only allow reversal if the batch has not yet been distributed
    if (b.status == Status.DISTRIBUTED || b.status == Status.DISPOSED) revert CannotUndoRecall();
    b.recalled = false;
    emit BatchRecallReverted(serialNumber, msg.sender);
}
```

Using `onlyAdmin` (not `onlyAuditor`) means a different role must confirm the reversal,
making accidental misuse harder. This is optional — the one-way latch is a valid safety
design choice; this REC only applies if operational error correction is a priority.

---

## Summary Table

| #      | Finding                                          | Severity | Effort  | Impact |
| ------ | ------------------------------------------------ | -------- | ------- | ------ |
| REC-01 | Add missing recall transition paths              | Medium   | Low     | High   |
| REC-02 | Add custody check before transitions             | Medium   | Medium  | High   |
| REC-03 | `initialAdmin` constructor parameter             | Medium   | Low     | Medium |
| REC-04 | Add `updateUserRole` function                    | Medium   | Low     | Medium |
| REC-05 | Fix `recalled` flag ordering (CEI)               | Low      | Trivial | Low    |
| REC-06 | Enforce expiry at distribution                   | Low      | Low     | Medium |
| REC-07 | Restrict `certifyBatch` to DISTRIBUTED           | Low      | Trivial | Low    |
| REC-08 | Document/clarify `STORED → DISPOSED` matrix      | Low      | Trivial | Low    |
| REC-09 | Validate `location != bytes32(0)` in transitions | Low      | Trivial | Low    |
| REC-10 | Make `getBatch`/`getUser` revert on missing key  | Low      | Trivial | Low    |
| REC-11 | Add `BatchDisposed` event                        | Info     | Trivial | Low    |
| REC-12 | `activateUser` idempotency guard                 | Info     | Trivial | Low    |
| REC-13 | `uint8` overflow custom error                    | Info     | Trivial | Low    |
| REC-14 | Missing invariant test                           | Info     | Trivial | Low    |
| REC-15 | Missing unit tests for `createBatch`             | Info     | Low     | Low    |
| REC-16 | Admin override for erroneous recalls (optional)  | Info     | Low     | Low    |
