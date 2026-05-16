# TrustChain — Smart Contracts

Blockchain supply chain traceability system built with Solidity 0.8.28 and Foundry.
Tracks product batches (food, pharma, industrial goods) from production to final distribution
using role-based access control and an immutable on-chain event log.

**Tech stack:** Solidity 0.8.28 · Foundry · Anvil · Slither · Solhint

---

## Project Structure

```
contracts/
├── src/
│   ├── DataTypes.sol       # enums (Role, Status, Category) + structs (User, Batch)
│   ├── ITrustChain.sol     # interface — function signatures, events, custom errors
│   └── TrustChain.sol      # main contract
├── test/
│   ├── TrustChainTestBase.t.sol   # shared fixtures and helpers
│   ├── TrustChain.t.sol           # unit tests
│   ├── TrustChain.fuzz.t.sol      # fuzz tests
│   ├── TrustChain.invariant.t.sol # invariant tests
│   └── TrustChain.e2e.t.sol       # end-to-end workflow tests
├── script/
│   └── Deploy.s.sol        # deploys contract + seeds 10 batches and 2 complete routes
└── foundry.toml
```

---

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) — `forge`, `anvil`
- [Slither](https://github.com/crytic/slither) — `pip install slither-analyzer`
- [Solhint](https://github.com/protofire/solhint) — `npm install -g solhint`

All commands below run from the `contracts/` directory.

---

## Quick Start

```shell
# 1. Build
forge build

# 2. Run tests
forge test

# 3. Start local blockchain + deploy
anvil &
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

---

## Testing

```shell
# Run all 106 tests (unit + fuzz + invariant + e2e)
forge test

# Show test names as they run
forge test -v

# Show logs and traces on failures
forge test -vvv

# Run a specific test by name
forge test --match-test test_createBatch_success -vv

# Run a specific test file
forge test --match-path test/TrustChain.t.sol -v

# Gas snapshot
forge snapshot

# Coverage report (requires lcov installed)
forge coverage --report lcov && genhtml lcov.info -o coverage/
```

---

## Deploy (local Anvil)

Uses Anvil's built-in default accounts — no private key flag needed.

```shell
# Terminal 1 — start local blockchain
anvil

# Terminal 2 — deploy and seed demo data
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

The deploy script registers 5 users and creates 10 batches across 7 product types,
then walks two complete routes:

| Route | Batch | Final state |
|-------|-------|-------------|
| Forward chain | `OLIVE-GR-001` | DISTRIBUTED + certified |
| Recall + dispose | `PHARMA-GR-001` | DISPOSED |

---

## Security Audit

### Solhint (linting + best practices)

```shell
# Terminal output
solhint "src/**/*.sol"

# Save table report to docs/
solhint "src/**/*.sol" --formatter table > ../docs/solhint-report.txt

# Save JSON report to docs/
solhint "src/**/*.sol" --formatter json > ../docs/solhint-report.json
```

### Slither (vulnerability detection)

```shell
# Terminal output
slither src/TrustChain.sol

# Save checklist report to docs/
slither src/TrustChain.sol --checklist 2>/dev/null > ../docs/slither-report.md
```

Audit findings are documented in [`../docs/security-audit.md`](../docs/security-audit.md).

---

## Code Quality

```shell
# Auto-format all Solidity files
forge fmt

# Check formatting without writing
forge fmt --check
```
