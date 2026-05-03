# Gas and Storage Analysis

---

## 1. Storage Layout

### 1.1 User Struct (2 slots)

```solidity
struct User {
    // Slot 0 — 28 bytes used (4 bytes wasted)
    address ethAddress;   // 20 bytes
    Role    role;         //  1 byte  (enum = uint8)
    bool    isActive;     //  1 byte
    uint48  registeredAt; //  6 bytes
    // Slot 1 — 32 bytes
    bytes32 name;         // 32 bytes
}
```

**Assessment:** Near-optimal. Slot 0 uses 28 of 32 bytes; the remaining 4 bytes are
unavoidable padding (smallest type would be `uint32`, consuming all remaining space, but
there is no obvious 4-byte field to add). Slot 1 is fully used. **2 slots = minimum possible
for this data.**

---

### 1.2 Batch Struct (5 slots)

```solidity
struct Batch {
    // Slot 0 — 32 bytes (perfectly packed)
    uint128  quantity;      // 16 bytes
    uint48   creationDate;  //  6 bytes
    uint48   expiryDate;    //  6 bytes
    uint8    productTypeId; //  1 byte
    Category category;      //  1 byte (enum)
    Status   status;        //  1 byte (enum)
    bool     recalled;      //  1 byte

    // Slot 1 — 22 bytes used (10 bytes wasted)
    address  producer;      // 20 bytes
    uint8    unitId;        //  1 byte
    bool     certified;     //  1 byte

    // Slot 2 — 20 bytes used (12 bytes wasted)
    address  currentHolder; // 20 bytes

    // Slot 3 — 32 bytes
    bytes32  origin;        // 32 bytes

    // Slot 4 — 32 bytes
    bytes32  serialNumber;  // 32 bytes
}
```

**Slot 0 — Perfect.** All 32 bytes are used. Critically, `status` and `recalled` share the
same slot — every state transition reads both in a single SLOAD. This is a smart and
intentional packing choice.

**Slot 1 — 10 bytes wasted.** `producer` (20 bytes) + `unitId` (1 byte) + `certified`
(1 byte) = 22 bytes. The remaining 10 bytes cannot be filled without adding new fields.
A `uint80` timestamp (10 bytes) could fill it exactly — e.g., a `lastTransitionAt` field —
but this is an optional enhancement.

**Slot 2 — 12 bytes wasted.** `currentHolder` (20 bytes) alone in a slot. The remaining
12 bytes cannot be trivially filled without a redesign. A `uint96` counter or flag field
could use 4–12 bytes here.

**Slots 3 & 4 — Full.** `bytes32` fields always fill exactly one slot.

**Overall:** 5 slots per batch. Minimum possible without combining fields is 4 slots
(which would require cramming `producer` and `currentHolder` into the same slot — impossible
since each is 20 bytes). **5 slots is optimal for this data model.**

---

### 1.3 Contract-Level Storage Layout

| Variable             | Type                                         | Slots                               |
| -------------------- | -------------------------------------------- | ----------------------------------- |
| `users`              | `mapping(address => User)`                   | 1 (slot pointer) + 2 per user       |
| `batches`            | `mapping(bytes32 => Batch)`                  | 1 (slot pointer) + 5 per batch      |
| `productTypeCount`   | `uint8`                                      | Shares slot with `unitCount`        |
| `productTypeNames`   | `mapping(uint8 => string)`                   | 1 + dynamic per name                |
| `unitCount`          | `uint8`                                      | Shares slot with `productTypeCount` |
| `unitNames`          | `mapping(uint8 => string)`                   | 1 + dynamic per name                |
| `allowedTransitions` | `mapping(Status => mapping(Status => bool))` | 1 + 1 per defined transition        |

**Note:** `productTypeCount` and `unitCount` are consecutive `uint8` state variables.
In Solidity, they are stored in **separate storage slots** (consecutive slot numbers),
not packed together. State variable packing only occurs within structs, not between
top-level state variables unless they are declared as packed types.

---

## 2. Gas Cost Estimates (EIP-2929 post-Berlin)

### 2.1 Per-Operation Costs

| Operation                    | Dominant Cost                               | Estimated Gas        |
| ---------------------------- | ------------------------------------------- | -------------------- |
| `createBatch`                | 5 × SSTORE (new slots)                      | ~120,000–130,000 gas |
| `registerUser`               | 2 × SSTORE (new slots)                      | ~50,000 gas          |
| `shipBatch` / `receiveBatch` | 2 × SSTORE (status+recalled, currentHolder) | ~25,000–30,000 gas   |
| `recallBatch`                | 3 × SSTORE (status+recalled+recalled flag)  | ~35,000–40,000 gas   |
| `certifyBatch`               | 1 × SSTORE (certified flag)                 | ~22,000 gas          |
| `disposeBatch`               | 2 × SSTORE (status)                         | ~25,000–30,000 gas   |
| `addProductType`             | 1 × SSTORE (string) + O(n) SLOADs           | ~22,000 + ~100n gas  |

`createBatch` is the most expensive user-facing operation. 5 SSTOREs at ~20,000 gas each
(first write) is ~100,000 gas for the struct alone, plus event emission and calldata costs.

### 2.2 `allowedTransitions` Matrix Storage Cost

The constructor writes 9 boolean transitions:

```
9 × SSTORE (cold, new slot) ≈ 9 × 20,000 = 180,000 gas
```

Since booleans (`false = 0`) at fresh storage slots already contain the zero value, only
the 9 `true` entries cost a full SSTORE. The implicit `false` transitions cost nothing.

**Optimization opportunity (minor):** Replace the storage mapping with a `pure` function
containing a hardcoded conditional. This saves ~180,000 gas on deployment and ~2,100 gas
per transition check (SLOAD → JUMP). For an academic contract this is not worth the
complexity, but noted for production consideration.

---

## 3. O(n) Loop Analysis

Two internal functions use a linear scan:

```solidity
function _addProductType(string memory name) internal {
    bytes32 nameHash = keccak256(bytes(name));
    for (uint8 i = 0; i < productTypeCount; i++) {
        if (keccak256(bytes(productTypeNames[i])) == nameHash) revert DuplicateProductType();
    }
    ...
}
```

| Loop              | Bounded By                   | Max Iterations | Max Gas per Call          |
| ----------------- | ---------------------------- | -------------- | ------------------------- |
| `_addProductType` | `productTypeCount` (`uint8`) | 255            | ~25,500 (SLOAD-dominated) |
| `_addUnit`        | `unitCount` (`uint8`)        | 255            | ~25,500 (SLOAD-dominated) |
| `getProductTypes` | `productTypeCount`           | 255            | ~25,500 (view, no SSTORE) |
| `getUnits`        | `unitCount`                  | 255            | ~25,500 (view)            |

All loops are `uint8`-bounded. The maximum gas cost is predictable and capped. No DoS
via gas exhaustion is possible because:

1. Only admins can call `addProductType`/`addUnit`.
2. The loop is bounded to 255 iterations.
3. The block gas limit (~30M) is far above 25,500.

**O(1) alternative:** Add a reverse mapping `mapping(bytes32 => bool) productTypeExists`.
Saves ~2,100 gas per check at the cost of one extra SSTORE per `addProductType` call.
Not necessary for this scope.

---

## 4. Event Gas Cost

Every state-changing function emits at least one event. Events cost:

- Base log opcode: ~375 gas
- Per 32-byte topic: ~375 gas
- Per 32-byte data word: ~8 gas (memory) + minimal calldata

`BatchTransitioned` is the most data-rich event:

```solidity
event BatchTransitioned(
    bytes32 indexed serialNumber,  // topic
    Status indexed from,           // topic
    Status indexed to,             // topic
    bytes32 location,              // data
    address by,                    // data
    uint48 at                      // data
);
```

3 indexed topics + 3 data words ≈ ~1,500–2,000 gas per emission. Acceptable.

**Note:** The maximum number of indexed topics is 3 in Solidity. `BatchTransitioned` uses
all 3, which is correct since `serialNumber`, `from`, and `to` are the most useful filter
dimensions for off-chain indexers.

---

## 5. Location as Event-Only Data (Design Choice Review)

The design spec explicitly states:

> "Location is NOT in the struct. Transit locations are captured only in `BatchTransitioned` events."

**Gas savings:** Each lifecycle transition costs one fewer SSTORE (save ~20,000 gas per hop)
by not persisting `location` in the struct.

**Trade-off:** Location is not queryable via `getBatch()`. To find the current location, a
client must scan all `BatchTransitioned` events for a given serialNumber and take the most
recent one. This requires an off-chain indexer (The Graph, custom backend) or iterating
over event logs.

**Assessment:** Correct and deliberate trade-off for this use case. Supply chain frontends
always maintain an off-chain index of events anyway. The gas saving per transition is
significant given the expected frequency of shipments.

---

## 6. Compiler Settings

From `foundry.toml`:

```toml
optimizer = true
optimizer_runs = 200
```

`optimizer_runs = 200` is the standard deployment optimization target — optimizes for the
expected number of times each function is called post-deployment. For a contract where
`createBatch` and `shipBatch` are called frequently, a higher value (e.g., 1000) could
reduce execution costs at the expense of slightly higher deployment bytecode size.

For academic use, 200 is fine. For production, consider profiling with `--optimizer-runs 1000`.
