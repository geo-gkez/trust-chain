// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {TrustChain} from "../src/TrustChain.sol";
import {Role, Category} from "../src/DataTypes.sol";

/// @dev Shared fixture for every test contract in the suite.
/// Declares no `test_*` / `testFuzz_*` / `invariant_*` functions, so it never runs on its own.
abstract contract TrustChainTestBase is Test {
    TrustChain internal tc;

    // The test contract deploys TrustChain, so address(this) = ADMIN
    address internal admin = address(this);

    address internal alice = makeAddr("Alice");
    address internal bob = makeAddr("Bob");
    address internal charlie = makeAddr("Charlie");
    address internal distributor = makeAddr("Distributor");
    address internal auditor = makeAddr("Auditor");

    bytes32 internal constant SERIAL = "BATCH-001";
    bytes32 internal constant LOC_A = "WH-ATHENS";
    bytes32 internal constant LOC_B = "TRUCK-007";
    bytes32 internal constant LOC_C = "DIST-PIR";

    function setUp() public virtual {
        tc = new TrustChain();
    }

    /// Register all five role accounts and create one seed batch (status = PRODUCED, holder = alice).
    function _registerAll() internal {
        tc.registerUser(alice, "Alice Producer", Role.PRODUCER);
        tc.registerUser(bob, "Bob Transporter", Role.TRANSPORTER);
        tc.registerUser(charlie, "Charlie Warehouse", Role.WAREHOUSE);
        tc.registerUser(distributor, "Distributor", Role.DISTRIBUTOR);
        tc.registerUser(auditor, "Auditor", Role.AUDITOR);

        vm.prank(alice);
        tc.createBatch(SERIAL, 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 0);
    }

    /// Advance batch to STORED (PRODUCED → STORED via receiveBatch).
    function _toStored() internal {
        _registerAll();
        vm.prank(alice);
        tc.transferCustody(SERIAL, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);
    }

    /// Advance batch to IN_TRANSIT (PRODUCED → IN_TRANSIT via shipBatch).
    function _toInTransit() internal {
        _registerAll();
        vm.prank(alice);
        tc.transferCustody(SERIAL, bob);
        vm.prank(bob);
        tc.shipBatch(SERIAL, LOC_B);
    }

    /// Advance batch to DISTRIBUTED (STORED → DISTRIBUTED).
    function _toDistributed() internal {
        _toStored();
        vm.prank(charlie);
        tc.transferCustody(SERIAL, distributor);
        vm.prank(distributor);
        tc.distributeBatch(SERIAL, LOC_C);
    }

    /// Advance batch to STORED *after recall* (DISTRIBUTED → RECALLED → STORED).
    /// `recalled` flag is true, status is STORED — the only legal entry state for disposeBatch.
    function _toRecalledStored() internal {
        _toDistributed();
        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C);
        // auditor is now currentHolder; hand off to warehouse for disposal
        vm.prank(auditor);
        tc.transferCustody(SERIAL, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);
    }
}
