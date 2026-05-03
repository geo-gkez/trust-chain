# Architecture Review

---

## 1. File Organization

```
contracts/src/
├── DataTypes.sol       # Pure type definitions — no logic, no imports
├── ITrustChain.sol     # Interface — all public signatures, events, custom errors
└── TrustChain.sol      # Single implementation contract
```

### Verdict: Clean and well-structured

The separation into three files follows the **interface segregation principle** well:

- `DataTypes.sol` contains zero logic — only `enum` and `struct` declarations. This file can be
  imported by any off-chain tooling (ABI codec, frontend, other contracts) without pulling in
  any implementation.
- `ITrustChain.sol` defines the full contract surface: function signatures, all events, and all
  custom errors. Declaring errors on the interface (rather than on the implementation) is the
  correct Solidity pattern — it allows callers to decode reverts without importing the
  implementation.
- `TrustChain.sol` is a single implementation contract with no inheritance from external
  libraries. This is appropriate given the academic scope and keeps the attack surface
  predictable.

---

## 2. Design Patterns Used

### 2.1 Custom Role-Based Access Control (RBAC)

```solidity
modifier onlyAdmin()       { _requireRole(msg.sender, Role.ADMIN); _; }
modifier onlyProducer()    { _requireRole(msg.sender, Role.PRODUCER); _; }
// ... etc
```

**Decision rationale:** Custom RBAC over OpenZeppelin `AccessControl`.  
OZ's `AccessControl` uses `bytes32` role identifiers and a dynamic role graph. For a fixed
six-role system, a `Role` enum is cleaner, cheaper (single slot), and less surface area.
The design doc correctly identifies this trade-off.

**Downside not documented:** OZ `AccessControl` supports multiple accounts per role and
role admin assignment natively. With the custom approach, each user has exactly one role.
If a single address needs to perform actions across multiple roles (e.g., a WAREHOUSE that
also manages ADMIN duties), it cannot — a new Ethereum address would be required.

### 2.2 Transition Matrix

```solidity
mapping(Status => mapping(Status => bool)) public allowedTransitions;
```

This is a well-chosen pattern for explicit state machine enforcement. Key properties:

- The matrix is public, making the allowed transitions queryable on-chain and from the UI.
- It's initialized once in the constructor and never modified — effectively immutable state.
- `_transition` is a single internal function that all lifecycle functions delegate to, ensuring
  the guard is never bypassed.

**Concern:** Because the matrix is stored in mutable mappings (not `immutable` or `constant`),
a future upgrade path could technically add an admin function to modify transitions. No such
function exists today, but the pattern is worth noting. If the transitions were truly constant
by design, they should be expressed as constants or a `pure` lookup function.

### 2.3 Storage Reference Pattern (Overloaded `_transition`)

```solidity
// Overload 1: caller already holds storage ref
function _transition(Batch storage b, bytes32 serialNumber, Status to, bytes32 location) internal

// Overload 2: loads from storage and delegates to overload 1
function _transition(bytes32 serialNumber, Status to, bytes32 location) internal
```

Smart use of function overloading. Functions that call `_requireBatch` before `_transition`
(e.g., `distributeBatch`, `recallBatch`, `certifyBatch`) reuse the storage reference to avoid
a second SLOAD. Functions that don't need pre-read (`receiveBatch`, `shipBatch`) call the
simpler overload. Saves ~200 gas per lifecycle hop.

### 2.4 `_requireXxx` Helper Pattern

```solidity
function _requireRegistered(address account) internal view returns (User storage u) { ... }
function _requireBatch(bytes32 serialNumber) internal view returns (Batch storage b) { ... }
```

Returning `storage` references from require-helpers is an elegant and gas-efficient pattern.
The caller gets both the validation and the reference in one call:

```solidity
_requireRegistered(user).isActive = false;  // validate + mutate in one line
```

This pattern is used consistently throughout the contract.

---

## 3. Constructor Design

```solidity
constructor() {
    _registerUser(msg.sender, "Admin", Role.ADMIN);
    _addProductType("FOOD"); // ... 7 types
    _addUnit("KG");           // ... 7 units
    _setupTransitionMatrix();
}
```

**Positive:** The constructor seeds the registry with reasonable defaults so the contract is
immediately usable after deployment without any setup transactions.

**Concern — Single admin bootstrapping:**  
The deployer becomes the only admin. There is no way to designate a different address as admin
during deployment (no constructor parameter). In a real deployment scenario, you typically want
the admin to be a multisig (Gnosis Safe), not the EOA that ran the deployment script.

**Concern — Constructor gas cost:**  
The constructor executes 7 + 7 = 14 storage writes for product types and units, plus 9 storage
writes for the transition matrix, plus the admin user struct (2 slots). This is approximately:

- 14 × 1 SSTORE (strings) ≈ ~300,000 gas for names
- 9 × 1 SSTORE (bool values) ≈ ~180,000 gas for matrix
- 2 SSTORE for admin user ≈ ~44,000 gas

Total deployment gas is high for a single-admin use case. Acceptable for academic scope; in
production, pre-seeding should be evaluated against lazy initialization.

---

## 4. Interface and Error Design

### Custom Errors

All reverts use custom errors (introduced in Solidity 0.8.4):

```solidity
error Unauthorized();
error BatchNotFound();
error InvalidTransition(Status from, Status to);
// ...
```

This is best practice. Custom errors are:

- **Gas efficient:** ~3x cheaper than `revert("string")` — no string ABI encoding.
- **Semantically clear:** error names and parameters are self-documenting.
- **Frontend friendly:** viem / ethers.js decodes custom errors by selector.

`InvalidTransition(Status from, Status to)` is particularly well designed — it provides the
full context needed to debug a failed transition without any additional lookup.

### Missing Error

`activateUser` does not check whether the user is **already active**. Setting `isActive = true`
on an already-active user is idempotent, but it emits a `UserActivated` event, which could
mislead off-chain monitoring systems into thinking a previously deactivated user was just
re-enabled. A corresponding `AlreadyActive` error or guard would improve event semantics.

---

## 5. Visibility and Access Qualifiers

All state-changing functions are `external` (correct — `external` is cheaper than `public` for
external callers). All view functions are `external view`. Internal helpers are `internal`.

No state variables are inadvertently exposed as writable — all mappings are `public` (read-only
via auto-generated getter). The `allowedTransitions` matrix being public is a nice property for
UI transparency.

---

## 6. Inheritance and Upgradability

The contract does not inherit from any external contract, does not implement a proxy pattern,
and is not upgradeable. For academic scope this is correct. In a production deployment:

- A UUPS or Transparent Proxy would be needed to fix bugs without redeploying.
- Alternatively, a migration strategy (deploy new contract, copy critical state) would need to
  be designed.

Neither of these is a defect in the current scope — but the final report should acknowledge
the immutability of the deployed contract as a deployment assumption.
