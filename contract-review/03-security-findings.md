# Security Findings

All findings are classified using the standard severity scale:

- **Critical** — direct fund loss or total contract takeover possible
- **High** — significant loss of function or unauthorized state manipulation
- **Medium** — design-level vulnerability with realistic abuse path
- **Low** — correctness gap or weak invariant with limited exploit surface
- **Info** — code quality, clarity, or best-practice issue; no security impact

---

## CRITICAL — None

No critical vulnerabilities were found. The contract holds no ETH, has no payable functions,
and performs no external calls — the reentrancy attack surface is zero.

---

## HIGH — None

No high-severity vulnerabilities were found. Arithmetic is protected by Solidity 0.8.28's
built-in overflow/underflow revert semantics. There are no unchecked blocks.

---

## MEDIUM

---

### F-01 — Single-admin bootstrapping with no recovery path

**Severity:** Medium  
**Location:** `TrustChain.sol` — `constructor`, `deactivateUser`

**Description:**  
The constructor hard-codes `msg.sender` as the sole admin. While the admin can register
additional admins via `registerUser(..., Role.ADMIN)`, there is no constructor parameter
to designate a safe multisig at deploy time. If the deployment EOA is a throwaway hot wallet
and no secondary admin is added before the key is discarded, the system is permanently bricked.

```solidity
constructor() {
    _registerUser(msg.sender, "Admin", Role.ADMIN);  // hard-coded to deployer EOA
    ...
}
```

The `SelfDeactivation` guard correctly prevents the admin from deactivating themselves.
However, it does not prevent another admin (if registered) from deactivating the original admin.
In a two-admin scenario, each can deactivate the other, potentially locking both out.

**Proof of scenario:**

1. Admin A deploys contract.
2. Admin A registers Admin B.
3. Admin B deactivates Admin A.
4. Admin A cannot call `activateUser(adminA)` because they are deactivated.
5. Admin A is locked out permanently unless Admin B re-activates them.

The above is not necessarily an attack (Admin B may be acting correctly) but shows the
governance model lacks safeguards for multi-admin edge cases.

**Recommendation:**

- Accept a `address initialAdmin` constructor parameter so a multisig can be admin from genesis.
- Consider adding a "last admin guard": prevent deactivating a user if they are the last
  active admin. See [07-recommendations.md](./07-recommendations.md) for code snippet.

---

### F-04 — `recallBatch` only reachable from `DISTRIBUTED` state — no recall path for earlier stages

**Severity:** Medium  
**Location:** `TrustChain.sol` — `allowedTransitions` constructor setup

**Description:**  
The transition matrix only allows `DISTRIBUTED → RECALLED`. There is no path for recalling
a batch that is currently in `PRODUCED`, `STORED`, or `IN_TRANSIT` state.

```solidity
// Only recall path defined in constructor:
allowedTransitions[Status.DISTRIBUTED][Status.RECALLED] = true;
// Missing:
// allowedTransitions[Status.STORED][Status.RECALLED] = true;
// allowedTransitions[Status.IN_TRANSIT][Status.RECALLED] = true;
```

**Real-world impact:** If a pharmaceutical batch is found to be contaminated while sitting in
a warehouse (status: `STORED`), the auditor cannot recall it. The workaround would be to
forcibly distribute it first and then recall — but `distributeBatch` is reserved for the
DISTRIBUTOR role, and that actor would be deliberately distributing a known-contaminated
product to trigger the recall. This is a regulatory compliance failure for hazardous categories.

**Recommendation:** Add `STORED → RECALLED` and `IN_TRANSIT → RECALLED` transitions:

```solidity
allowedTransitions[Status.STORED][Status.RECALLED] = true;
allowedTransitions[Status.IN_TRANSIT][Status.RECALLED] = true;
```

Also add `PRODUCED → RECALLED` for batches found defective before leaving the factory.

---

### F-05 — No custody check before lifecycle transitions

**Severity:** Medium  
**Location:** `TrustChain.sol` — `shipBatch`, `receiveBatch`, `distributeBatch`

**Description:**  
Every lifecycle function checks the caller's role but never checks that the caller is the
current holder (`currentHolder`) of the batch. Any active TRANSPORTER can ship any batch,
regardless of whether they physically have it.

```solidity
function shipBatch(bytes32 serialNumber, bytes32 location) external onlyTransporter {
    _transition(serialNumber, Status.IN_TRANSIT, location);
    // No check: require(batches[serialNumber].currentHolder == msg.sender)
}
```

**Exploit scenario:**

1. Producer Alice creates `BATCH-001`.
2. Charlie (WAREHOUSE) receives it to `WH-ATHENS` — `currentHolder = charlie`.
3. Rogue transporter Bob (who has never been near Athens) calls `shipBatch("BATCH-001", "TRUCK-FAKE")`.
4. On-chain state: `currentHolder = bob`, `status = IN_TRANSIT`, location = `"TRUCK-FAKE"`.
5. The on-chain record is now fraudulent — the audit trail is corrupted.

The supply chain's primary value proposition (tamper-proof custody tracking) is undermined by
the absence of a custody check.

**Recommendation (lightweight):** Add `require(b.currentHolder == msg.sender)` inside
`_transition` or per-function. See [07-recommendations.md](./07-recommendations.md).

**Recommendation (production-grade):** Implement a two-party handshake — the current holder
initiates a transfer, the next actor accepts it. This models real custody transfer semantics.

---

### F-02 — No role-update mechanism — addresses are permanently locked to their initial role

**Severity:** Medium  
**Location:** `TrustChain.sol` — `registerUser`, `_registerUser`

**Description:**  
Once an address is registered, its role is immutable. `registerUser` delegates to
`_registerUser` which reverts with `AlreadyRegistered` for any duplicate. There is no
`updateUserRole` function.

In a real supply chain, personnel change roles (e.g., a warehouse worker promoted to
administrator, or a transporter reassigned to distribution). The only current workaround
is to deactivate the old address and register a new one — but the new address has no
on-chain history, breaking audit trail continuity for that actor. Any historical events
attributed to the old address are effectively orphaned from the new identity.

**Recommendation:** Add `function updateUserRole(address user, Role newRole) external onlyAdmin`.
See [07-recommendations.md](./07-recommendations.md) for the full code snippet.

---

## LOW

---

### F-03 — `recalled` flag set after `_transition` call — state ordering inconsistency

**Severity:** Low  
**Location:** `TrustChain.sol:163-168` — `recallBatch`

**Description:**  
In `recallBatch`, the `_transition` call (which emits `BatchTransitioned`) fires before
`b.recalled = true` is set. The `BatchTransitioned` event is emitted with `b.recalled == false`,
which is inconsistent with the final committed state.

```solidity
function recallBatch(bytes32 serialNumber, bytes32 location) external onlyAuditor {
    Batch storage b = _requireBatch(serialNumber);
    _transition(b, serialNumber, Status.RECALLED, location);  // event fires here
    b.recalled = true;                                         // set after event
    emit BatchRecalled(serialNumber, msg.sender);
}
```

In a single-transaction context there is no reentrancy risk (no external calls), but the
"checks-effects-interactions" (CEI) principle still recommends writing state before emitting
events. An off-chain indexer reading the state at the time of the `BatchTransitioned` event
would observe `recalled == false` even for a RECALLED batch.

**Recommendation:**

```solidity
function recallBatch(bytes32 serialNumber, bytes32 location) external onlyAuditor {
    Batch storage b = _requireBatch(serialNumber);
    b.recalled = true;                                         // write state first
    _transition(b, serialNumber, Status.RECALLED, location);
    emit BatchRecalled(serialNumber, msg.sender);
}
```

---

### F-06 — Expiry date not enforced at distribution time

**Severity:** Low  
**Location:** `TrustChain.sol` — `distributeBatch`, `_transition`

**Description:**  
`expiryDate` is validated at creation (cannot register an already-expired batch), but it is
never re-checked during subsequent lifecycle transitions. A batch can be distributed to
consumers after its expiry date has passed.

```solidity
// createBatch — correct guard:
if (expiryDate != 0 && expiryDate < block.timestamp) revert InvalidExpiryDate();

// distributeBatch — no expiry check:
function distributeBatch(bytes32 serialNumber, bytes32 location) external onlyDistributor {
    Batch storage b = _requireBatch(serialNumber);
    if (b.recalled) revert CannotDistributeRecalled();
    _transition(b, serialNumber, Status.DISTRIBUTED, location);
    // Missing: if (b.expiryDate != 0 && b.expiryDate < block.timestamp) revert BatchExpired();
}
```

**Recommendation:**  
Add an expiry check inside `distributeBatch`. For perishable/pharmaceutical categories,
consider enforcing at all transitions, not just distribution.

---

### F-12 — Transition matrix allows `STORED → DISPOSED` but `disposeBatch` requires `recalled == true`

**Severity:** Low  
**Location:** `TrustChain.sol` — constructor, `disposeBatch`

**Description:**  
The transition matrix permits `STORED → DISPOSED`, but `disposeBatch` adds an application-level
guard `if (!b.recalled) revert BatchNotRecalled()`. These two layers tell slightly different
stories: the matrix says "STORED can become DISPOSED", while the function says "only if
recalled".

```solidity
// Matrix says: STORED → DISPOSED is valid
allowedTransitions[Status.STORED][Status.DISPOSED] = true;

// Function adds extra guard the matrix doesn't encode:
function disposeBatch(...) external onlyWarehouse {
    Batch storage b = _requireBatch(serialNumber);
    if (!b.recalled) revert BatchNotRecalled();   // extra guard not in matrix
    _transition(b, serialNumber, Status.DISPOSED, location);
}
```

The `_transition` internal function is the sole enforcement point for the matrix. If any
future function calls `_transition` directly to `DISPOSED` without the `recalled` guard,
a non-recalled batch could be disposed. The current code is safe, but the matrix is
semantically incomplete.

**Recommendation:** Remove `STORED → DISPOSED` from the transition matrix. Instead, encode
the transition only through the application-level guard in `disposeBatch`. This eliminates
the matrix inconsistency and makes the state machine the single source of truth.

---

### F-13 — `certifyBatch` callable before distribution — no lifecycle ordering constraint

**Severity:** Low  
**Location:** `TrustChain.sol:171-180` — `certifyBatch`

**Description:**  
The assignment specifies that an auditor certifies a batch after distribution (the standard
regulatory model: certify after inspection at point of sale). The current implementation
allows certifying a batch in any non-RECALLED, non-DISPOSED state — including `PRODUCED`,
`STORED`, or `IN_TRANSIT`.

```solidity
function certifyBatch(bytes32 serialNumber) external onlyAuditor {
    Batch storage b = _requireBatch(serialNumber);
    if (b.status == Status.RECALLED || b.status == Status.DISPOSED) {
        revert CannotCertifyInStatus(b.status);
    }
    if (b.certified) revert AlreadyCertified();
    b.certified = true;
    emit BatchCertified(serialNumber, msg.sender);
}
```

**Real-world impact:** An auditor can certify a batch that hasn't reached its destination yet.
This creates misleading audit records and could be exploited to pre-certify fraudulent batches.

**Recommendation:**  
Restrict certification to `DISTRIBUTED` status:

```solidity
if (b.status != Status.DISTRIBUTED) revert CannotCertifyInStatus(b.status);
```

---

### F-15 — `location == bytes32(0)` accepted silently in all lifecycle functions

**Severity:** Low  
**Location:** `TrustChain.sol` — `receiveBatch`, `shipBatch`, `distributeBatch`, `recallBatch`, `disposeBatch`

**Description:**  
`createBatch` correctly rejects `origin == bytes32(0)` with `InvalidOrigin`. However, every
lifecycle function that accepts a `location` parameter passes it directly to `_transition`
with no zero-check:

```solidity
function shipBatch(bytes32 serialNumber, bytes32 location) external onlyTransporter {
    _transition(serialNumber, Status.IN_TRANSIT, location);
    // No check: if (location == bytes32(0)) revert InvalidLocation();
}
```

`BatchTransitioned` events with `location == bytes32(0)` will appear in the audit trail as
meaningless zero-location hops. This is asymmetric with the `origin` validation and silently
corrupts the location history that is the contract's primary audit mechanism.

**Recommendation:** Add a zero-check in `_transition`:

```solidity
if (location == bytes32(0)) revert InvalidLocation();
```

Add `error InvalidLocation();` to `ITrustChain.sol`.

---

### F-16 — `getBatch` / `getUser` return a zeroed struct for non-existent keys

**Severity:** Low  
**Location:** `TrustChain.sol` — `getBatch`, `getUser`

**Description:**  
Both view functions return a fully zeroed struct for keys that do not exist:

```solidity
function getBatch(bytes32 serialNumber) external view returns (Batch memory) {
    return batches[serialNumber];  // returns zero struct if key absent
}
```

An external caller (frontend, integrating contract) cannot cleanly distinguish "batch not
found" from "batch exists with all-zero fields" without knowing to check
`returnedBatch.serialNumber == bytes32(0)`. The `_requireBatch` guard used internally is
not surfaced to external callers. A frontend bug that fails to perform this sentinel check
would silently process phantom batches.

**Recommendation:** Either document the sentinel check explicitly in NatSpec, or make the
view functions revert on non-existence:

```solidity
function getBatch(bytes32 serialNumber) external view returns (Batch memory) {
    return _requireBatch(serialNumber);
}
```

---

## INFO

---

### F-17 — No mechanism to reverse an erroneous recall

**Severity:** Info  
**Location:** `TrustChain.sol` — `recallBatch`

**Description:**  
The `recalled` flag is a permanent one-way latch — once set to `true`, no function can
clear it. An auditor who recalls the wrong batch (typo in serial number, mistaken identity)
has no administrative override. The batch is permanently flagged as recalled and can never
be re-distributed, even after the error is discovered.

This is a deliberate design choice — the one-way latch is a valuable safety property
that prevents re-distribution of genuinely unsafe goods. But it also means operational
errors are irreversible.

**Recommendation (optional):** Add an admin-only `unrecallBatch` with a guard that prevents
abuse:

```solidity
function unrecallBatch(bytes32 serialNumber) external onlyAdmin {
    Batch storage b = _requireBatch(serialNumber);
    if (b.status == Status.DISTRIBUTED) revert CannotUndoRecall();
    b.recalled = false;
    emit BatchRecallReverted(serialNumber, msg.sender);
}
```

Restricting to `onlyAdmin` (not `onlyAuditor`) adds a second-factor check — a different
role must confirm the reversal, making accidental abuse harder.

---

### F-07 — `activateUser` emits `UserActivated` even when user is already active

**Severity:** Info  
**Location:** `TrustChain.sol:103-106` — `activateUser`

**Description:**  
`activateUser` is idempotent (setting `true` to `true` is a no-op), but it emits
`UserActivated` unconditionally. Off-chain indexers that track deactivation/activation
history will receive spurious events.

```solidity
function activateUser(address user) external onlyAdmin {
    _requireRegistered(user).isActive = true;
    emit UserActivated(user);   // fires even if user was already active
}
```

---

### F-08 — `disposeBatch` has no dedicated event

**Severity:** Info  
**Location:** `TrustChain.sol` — `disposeBatch`

**Description:**  
`recallBatch` emits both `BatchTransitioned` (via `_transition`) **and** `BatchRecalled`.
`certifyBatch` emits `BatchCertified`. But `disposeBatch` only emits `BatchTransitioned` —
there is no `BatchDisposed` event. This creates an inconsistency in event granularity
and makes it harder for off-chain systems to specifically monitor disposal events.

---

### F-09 — O(n) duplicate check in `_addProductType` / `_addUnit`

**Severity:** Info  
**Location:** `TrustChain.sol:242-258` — `_addProductType`, `_addUnit`

**Description:**  
Duplicate detection uses a linear scan of all existing names:

```solidity
for (uint8 i = 0; i < productTypeCount; i++) {
    if (keccak256(bytes(productTypeNames[i])) == nameHash) revert DuplicateProductType();
}
```

Each iteration reads a storage slot (SLOAD, ~100 gas cold). With 255 product types, the
255th addition costs ~25,500 gas just for duplicate checking. This is technically bounded
(uint8 max = 255), admin-only, and rare — so the impact is negligible in practice.

---

### F-10 — `uint8` overflow on `productTypeCount` / `unitCount` gives confusing revert

**Severity:** Info  
**Location:** `TrustChain.sol` — `_addProductType`, `_addUnit`

**Description:**  
If `productTypeCount` reaches 255 and `_addProductType` is called again, Solidity 0.8.x
will revert on `productTypeCount++` with a generic arithmetic overflow panic (0x11), not a
custom error. This is not a security issue (it's the correct behavior), but a confusing
user/developer experience.

---

### F-11 — `bytes32` name fields silently truncate strings longer than 32 bytes

**Severity:** Info  
**Location:** `DataTypes.sol` — `User.name`, `Batch.serialNumber`, `Batch.origin`

**Description:**  
`bytes32` parameters in the ABI do not validate string length. In JavaScript/TypeScript:

```js
ethers.encodeBytes32String("A-VERY-LONG-SERIAL-NUMBER-THAT-EXCEEDS-32-CHARS");
// throws at the ethers.js layer — safe
```

However, raw `bytes32` hex encoding can silently truncate. The risk is in UI input handling,
not in the contract itself. The contract correctly stores whatever 32-byte value it receives.

---

### F-14 — No batch quantity splitting mechanism

**Severity:** Info  
**Location:** `TrustChain.sol` — design gap

**Description:**  
Batch quantity is set at creation and never modified. Real supply chains routinely split
shipments (e.g., 1000 kg olive oil split into 10 × 100 kg deliveries). The current model
treats the entire batch as atomic.

This is an academic scope limitation, not a defect, but it constrains real-world applicability.
