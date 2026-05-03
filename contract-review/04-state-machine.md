# State Machine Analysis

---

## 1. Defined States

```solidity
enum Status { PRODUCED, STORED, IN_TRANSIT, DISTRIBUTED, RECALLED, DISPOSED }
```

| State         | Description                              | Terminal?     |
| ------------- | ---------------------------------------- | ------------- |
| `PRODUCED`    | Batch created by producer, not yet moved | No            |
| `STORED`      | Received at warehouse                    | No            |
| `IN_TRANSIT`  | Picked up by transporter                 | No            |
| `DISTRIBUTED` | Delivered to final point of sale         | Yes (normal)  |
| `RECALLED`    | Flagged unsafe by auditor                | No            |
| `DISPOSED`    | Destroyed/discarded recalled goods       | Yes (reverse) |

---

## 2. Allowed Transitions (as implemented)

The transition matrix is initialized in the constructor:

```
PRODUCED    → STORED          (WAREHOUSE — receiveBatch)
PRODUCED    → IN_TRANSIT      (TRANSPORTER — shipBatch)
STORED      → IN_TRANSIT      (TRANSPORTER — shipBatch)
STORED      → DISTRIBUTED     (DISTRIBUTOR — distributeBatch)
STORED      → DISPOSED        (WAREHOUSE — disposeBatch, only if recalled=true)
IN_TRANSIT  → STORED          (WAREHOUSE — receiveBatch)
IN_TRANSIT  → DISTRIBUTED     (DISTRIBUTOR — distributeBatch)
DISTRIBUTED → RECALLED        (AUDITOR — recallBatch)
RECALLED    → STORED          (WAREHOUSE — receiveBatch)
```

### Visual Graph

```
                     ┌──────────────────────────────┐
                     ▼                              │
[PRODUCED] ──→ [STORED] ──→ [IN_TRANSIT] ──────┐  │
    │              │              │              │  │
    └──────────────┼──────────────┘              │  │
                   ▼                             ▼  │
              [STORED] ◄────────────────── [RECALLED]
                   │                             │
                   ▼                             │
            [DISTRIBUTED] ──────────────────────┘
                   │
                   ▼
              [DISPOSED]  (only via STORED + recalled=true)
```

A cleaner directed graph:

```
PRODUCED ──────────────────────────────────────────────────────────┐
    │                                                               │
    ▼                                                               ▼
STORED ◄──── IN_TRANSIT ◄──────────────────────────────────── PRODUCED
    │              │
    │              │
    ▼              ▼
DISTRIBUTED ◄── IN_TRANSIT
    │
    ▼
RECALLED
    │
    ▼
STORED ──(recalled=true)──► DISPOSED
```

---

## 3. Reachability Analysis

Starting from `PRODUCED`, can every state be reached?

| Target State  | Minimum Path                                                   | Reachable? |
| ------------- | -------------------------------------------------------------- | ---------- |
| `STORED`      | PRODUCED → STORED                                              | ✅         |
| `IN_TRANSIT`  | PRODUCED → IN_TRANSIT                                          | ✅         |
| `DISTRIBUTED` | PRODUCED → STORED → DISTRIBUTED                                | ✅         |
| `RECALLED`    | PRODUCED → STORED → DISTRIBUTED → RECALLED                     | ✅         |
| `DISPOSED`    | PRODUCED → STORED → DISTRIBUTED → RECALLED → STORED → DISPOSED | ✅         |

All states are reachable. The shortest path to `DISPOSED` is 5 transitions, which is realistic
for a real-world recall lifecycle.

---

## 4. Terminal State Analysis

Can a batch escape a terminal state?

| Terminal State | Can it transition OUT?                         |
| -------------- | ---------------------------------------------- |
| `DISTRIBUTED`  | ✅ Yes → `RECALLED` (via `recallBatch`)        |
| `DISPOSED`     | ❌ No — no outbound transition from `DISPOSED` |

Note: `DISTRIBUTED` is intended as the "normal terminal state" but it is NOT truly terminal —
it can transition to `RECALLED`. This is intentional and correctly models real-world recalls.

`DISPOSED` is the only true terminal state — there is no path out of it, which is correct.

---

## 5. Identified State Machine Gaps

### Gap A — No recall path before distribution (F-04)

**Critical gap.** The transition matrix only defines `DISTRIBUTED → RECALLED`. There is no
`STORED → RECALLED` or `IN_TRANSIT → RECALLED` transition. A contaminated pharmaceutical
batch sitting in a warehouse cannot be recalled without first being distributed.

**Missing transitions:**

```
PRODUCED    → RECALLED    (factory defect discovered)
STORED      → RECALLED    (contamination found in warehouse)
IN_TRANSIT  → RECALLED    (issue discovered during transport)
```

**Current workaround (broken):** The auditor would have to ask the distributor to
`distributeBatch` first, creating a fraudulent distribution record for a known-unsafe product.
This is a regulatory compliance violation for regulated product categories.

### Gap B — `STORED → DISPOSED` in matrix is misleading (F-12)

The transition matrix includes `STORED → DISPOSED`, but `disposeBatch` adds an extra guard
(`!b.recalled revert BatchNotRecalled`) that the matrix does not encode.

This creates a semantic inconsistency: the matrix says the transition is valid, but the
function says it is only valid under a specific condition. A developer reading only the matrix
would believe any STORED batch can be disposed, which is false.

### Gap C — `certifyBatch` has no state precondition (F-13)

`certifyBatch` can be called at any non-terminal state. An auditor can certify a batch that
is still at the producer or in a warehouse. Certification should be post-distribution to
reflect real-world regulatory sign-off.

---

## 6. Transition Enforcement — Role vs. Matrix

The contract enforces transitions at two levels:

| Level        | Enforced By            | Checked                                                  |
| ------------ | ---------------------- | -------------------------------------------------------- |
| Role check   | `onlyXxx` modifier     | Is the caller authorized to perform this type of action? |
| Matrix check | `_transition` internal | Is this state jump defined as valid?                     |

Both checks must pass. This creates a two-factor gate on every lifecycle transition.

**Note:** The role check is applied at the external function level. The matrix check is
applied inside `_transition`. If `_transition` were ever called directly (e.g., from a new
function without a role modifier), the matrix would still enforce valid jumps — but the role
check would be bypassed. Currently no such bypass exists.

---

## 7. Invariants Tested by the Test Suite

The invariant test suite (`TrustChain.invariant.t.sol`) verifies three invariants
using Foundry's stateful fuzzing:

| Invariant | Statement                                          | Test                                    |
| --------- | -------------------------------------------------- | --------------------------------------- |
| I-1       | `batch.producer` is immutable after creation       | `invariant_producerIsImmutable`         |
| I-2       | `status == DISPOSED` implies `recalled == true`    | `invariant_disposedImpliesRecalled`     |
| I-3       | `recalled == true` implies `status != DISTRIBUTED` | `invariant_recalledBatchNotDistributed` |

These are the three most important safety invariants of the contract. All three are correctly
specified and tested.

**Missing invariant (suggested):**  
`status == DISTRIBUTED && recalled == false` implies `certified` may be true or false.  
But `recalled == true` should imply `certified == false` (you cannot certify a recalled batch).
The current code correctly blocks this in `certifyBatch`, but there is no corresponding
invariant test to verify it under fuzz conditions.

---

## 8. `recalled` Flag Semantics

The `recalled` flag is a **one-way latch** — once set to `true`, it can never return to `false`.
No function in the contract sets `recalled = false` after it is set to `true`.

This is a critical correctness property. The invariant tests verify that:

- A recalled batch can never be re-distributed (I-3).
- A disposed batch was recalled (I-2).

The latch is correctly implemented and tested.
