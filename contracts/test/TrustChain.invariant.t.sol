// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TrustChainTestBase} from "./TrustChainTestBase.t.sol";
import {Status, Batch} from "../src/DataTypes.sol";

/// @notice Invariant (stateful fuzz) tests for TrustChain.
/// @dev Foundry picks random functions on the target contract, random senders
/// from our pool, random arguments, and chains `depth` calls (default 15).
/// After each sequence it runs every `invariant_*` function. Most role-gated
/// calls will revert — `fail-on-revert = false` tells Foundry to discard
/// reverts and keep exploring instead of aborting the test.
/// forge-config: default.invariant.fail-on-revert = false
contract TrustChainInvariantTest is TrustChainTestBase {
    function setUp() public override {
        super.setUp();

        // One seed batch + five registered role holders. Now the random driver
        // has a non-trivial state graph to explore (create more batches, ship,
        // store, distribute, recall, dispose, certify — from the right senders
        // most of the time, random sender the rest).
        _registerAll();

        targetContract(address(tc));

        // Pool Foundry samples from when picking `msg.sender` for each random call.
        // Without this, senders would be random EOAs — nearly every call would
        // revert on role checks and the state would never advance.
        targetSender(alice);
        targetSender(bob);
        targetSender(charlie);
        targetSender(distributor);
        targetSender(auditor);
    }

    /// Invariant 1: producer is immutable.
    /// No function in the contract should be able to overwrite `batch.producer`
    /// after `createBatch`. If a future refactor accidentally assigns to it in
    /// `_transition` or `recallBatch`, this invariant fails.
    function invariant_producerIsImmutable() public view {
        assertEq(tc.getBatch(SERIAL).producer, alice);
    }

    /// Invariant 2: DISPOSED implies recalled.
    /// The only path to DISPOSED is RECALLED → STORED → DISPOSED (enforced by
    /// the guard in `disposeBatch`). If any sequence produces a DISPOSED batch
    /// with `recalled == false`, the reverse-logistics invariant is broken.
    function invariant_disposedImpliesRecalled() public view {
        Batch memory b = tc.getBatch(SERIAL);
        if (b.status == Status.DISPOSED) {
            assertTrue(b.recalled);
        }
    }

    /// Invariant 3: a recalled batch is never DISTRIBUTED.
    /// The `recalled` flag is a one-way latch that `distributeBatch` refuses to
    /// cross. After a recall, the only way back to circulation would be through
    /// distribute, which reverts with `CannotDistributeRecalled`. So at any
    /// observed state, `recalled == true && status == DISTRIBUTED` is impossible.
    function invariant_recalledBatchNotDistributed() public view {
        Batch memory b = tc.getBatch(SERIAL);
        if (b.recalled) {
            assertTrue(b.status != Status.DISTRIBUTED);
        }
    }
}
