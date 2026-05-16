// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TrustChainTestBase} from "./TrustChainTestBase.t.sol";
import {ITrustChain} from "../src/ITrustChain.sol";
import {Role, Status, Category, Batch} from "../src/DataTypes.sol";

/// @notice End-to-end workflow tests for TrustChain.
/// Each test walks a complete lifecycle narrative across multiple actors,
/// asserting state at every hop so failures point to the exact step that broke.
contract TrustChainE2ETest is TrustChainTestBase {
    bytes32 internal constant OLIVE = "OLIVE-GR-001";
    bytes32 internal constant PHARMA = "PHARMA-GR-001";

    function setUp() public override {
        super.setUp();
        tc.registerUser(alice, "Alice Producer", Role.PRODUCER);
        tc.registerUser(bob, "Bob Transporter", Role.TRANSPORTER);
        tc.registerUser(charlie, "Charlie Warehouse", Role.WAREHOUSE);
        tc.registerUser(distributor, "Distributor", Role.DISTRIBUTOR);
        tc.registerUser(auditor, "Auditor", Role.AUDITOR);
    }

    /// Workflow 1 — Normal forward chain (olive oil)
    /// PRODUCED → STORED → IN_TRANSIT → STORED → IN_TRANSIT → DISTRIBUTED → certified
    function test_e2e_forwardChain() public {
        // Alice (PRODUCER) mints the batch
        vm.prank(alice);
        tc.createBatch(OLIVE, 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 0);
        assertEq(uint8(tc.getBatch(OLIVE).status), uint8(Status.PRODUCED));
        assertEq(tc.getBatch(OLIVE).currentHolder, alice);

        // Alice hands custody to Charlie (WAREHOUSE) at origin
        vm.prank(alice);
        tc.transferCustody(OLIVE, charlie);

        // Charlie receives at origin warehouse
        vm.prank(charlie);
        tc.receiveBatch(OLIVE, "WH-KALAMATA");
        assertEq(uint8(tc.getBatch(OLIVE).status), uint8(Status.STORED));
        assertEq(tc.getBatch(OLIVE).currentHolder, charlie);

        // Charlie hands custody to Bob (TRANSPORTER) for first leg
        vm.prank(charlie);
        tc.transferCustody(OLIVE, bob);

        // Bob picks up for first leg
        vm.prank(bob);
        tc.shipBatch(OLIVE, "TRUCK-001");
        assertEq(uint8(tc.getBatch(OLIVE).status), uint8(Status.IN_TRANSIT));

        // Bob hands custody to Charlie at hub warehouse
        vm.prank(bob);
        tc.transferCustody(OLIVE, charlie);

        // Charlie receives at hub warehouse
        vm.prank(charlie);
        tc.receiveBatch(OLIVE, "WH-ATHENS");
        assertEq(uint8(tc.getBatch(OLIVE).status), uint8(Status.STORED));

        // Charlie hands custody to Bob for final leg
        vm.prank(charlie);
        tc.transferCustody(OLIVE, bob);

        // Bob ships final leg
        vm.prank(bob);
        tc.shipBatch(OLIVE, "TRUCK-002");
        assertEq(uint8(tc.getBatch(OLIVE).status), uint8(Status.IN_TRANSIT));

        // Bob hands custody to distributor
        vm.prank(bob);
        tc.transferCustody(OLIVE, distributor);

        // Distributor delivers
        vm.prank(distributor);
        tc.distributeBatch(OLIVE, "DIST-PIR");
        assertEq(uint8(tc.getBatch(OLIVE).status), uint8(Status.DISTRIBUTED));

        // Auditor certifies after successful delivery (no custody check)
        vm.prank(auditor);
        tc.certifyBatch(OLIVE);

        Batch memory b = tc.getBatch(OLIVE);
        assertEq(uint8(b.status), uint8(Status.DISTRIBUTED));
        assertEq(b.producer, alice);
        assertFalse(b.recalled);
        assertTrue(b.certified);
    }

    /// Workflow 2 — Recall + reverse logistics (pharma)
    /// PRODUCED → STORED → IN_TRANSIT → DISTRIBUTED → RECALLED → STORED → DISPOSED
    function test_e2e_recallAndDispose() public {
        // Alice (PRODUCER) mints the pharma batch
        vm.prank(alice);
        tc.createBatch(PHARMA, 1, Category.REFRIGERATED, 0, 500, "GR-ATH", 0);
        assertEq(uint8(tc.getBatch(PHARMA).status), uint8(Status.PRODUCED));

        // Alice hands custody to Charlie (WAREHOUSE)
        vm.prank(alice);
        tc.transferCustody(PHARMA, charlie);

        // Charlie receives at origin warehouse
        vm.prank(charlie);
        tc.receiveBatch(PHARMA, "WH-ATHENS");
        assertEq(uint8(tc.getBatch(PHARMA).status), uint8(Status.STORED));

        // Charlie hands custody to Bob (TRANSPORTER)
        vm.prank(charlie);
        tc.transferCustody(PHARMA, bob);

        // Bob ships to distributor
        vm.prank(bob);
        tc.shipBatch(PHARMA, "TRUCK-PHARMA");
        assertEq(uint8(tc.getBatch(PHARMA).status), uint8(Status.IN_TRANSIT));

        // Bob hands custody to distributor
        vm.prank(bob);
        tc.transferCustody(PHARMA, distributor);

        // Distributor delivers
        vm.prank(distributor);
        tc.distributeBatch(PHARMA, "DIST-ATH");
        assertEq(uint8(tc.getBatch(PHARMA).status), uint8(Status.DISTRIBUTED));

        // Auditor recalls due to safety issue (no custody check — auditor override)
        vm.prank(auditor);
        tc.recallBatch(PHARMA, "DIST-ATH");
        assertEq(uint8(tc.getBatch(PHARMA).status), uint8(Status.RECALLED));
        assertTrue(tc.getBatch(PHARMA).recalled);

        // Auditor designates Charlie's warehouse for quarantine receipt
        vm.prank(auditor);
        tc.transferCustody(PHARMA, charlie);

        // Charlie receives into quarantine — recalled flag must survive the transition
        vm.prank(charlie);
        tc.receiveBatch(PHARMA, "WH-QUARANTINE");
        assertEq(uint8(tc.getBatch(PHARMA).status), uint8(Status.STORED));
        assertTrue(tc.getBatch(PHARMA).recalled);

        // recalled flag blocks re-distribution (recalled guard fires before custody check)
        vm.prank(distributor);
        vm.expectRevert(ITrustChain.CannotDistributeRecalled.selector);
        tc.distributeBatch(PHARMA, "DIST-ATH");

        // Charlie disposes the batch
        vm.prank(charlie);
        tc.disposeBatch(PHARMA, "WH-QUARANTINE");

        Batch memory b = tc.getBatch(PHARMA);
        assertEq(uint8(b.status), uint8(Status.DISPOSED));
        assertEq(b.producer, alice);
        assertTrue(b.recalled);
        assertFalse(b.certified);
    }
}
