// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TrustChainTestBase} from "./TrustChainTestBase.t.sol";
import {ITrustChain} from "../src/ITrustChain.sol";
import {Role, Status, Category, User, Batch} from "../src/DataTypes.sol";

contract TrustChainTest is TrustChainTestBase {
    // ── Constructor ─────────────────────────────────────────────────────

    function test_constructor_registersDeployerAsAdmin() public view {
        User memory u = tc.getUser(admin);
        assertEq(u.ethAddress, admin);
        assertEq(uint8(u.role), uint8(Role.ADMIN));
        assertTrue(u.isActive);
        assertEq(u.name, "Admin");
    }

    function test_constructor_seedsProductTypes() public view {
        string[] memory types = tc.getProductTypes();
        assertEq(types.length, 7);
        assertEq(types[0], "FOOD");
        assertEq(types[6], "TEXTILE");
    }

    function test_constructor_seedsUnits() public view {
        string[] memory units = tc.getUnits();
        assertEq(units.length, 7);
        assertEq(units[0], "KG");
        assertEq(units[6], "M2");
    }

    function test_constructor_seedsTransitionMatrix() public {
        // Verify the matrix behaviorally — a valid path succeeds, an invalid one reverts.
        _registerAll(); // SERIAL is PRODUCED, holder = alice

        // PRODUCED → STORED is seeded as valid
        _handoff(SERIAL, alice, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);
        assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.STORED));

        // PRODUCED → DISTRIBUTED is not seeded — a fresh batch cannot skip to distribution
        bytes32 other = "BATCH-002";
        vm.prank(alice);
        tc.createBatch(other, 0, Category.PERISHABLE, 0, 100, "GR-PEL", 0);
        _handoff(other, alice, distributor);
        vm.prank(distributor);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustChain.InvalidTransition.selector, Status.PRODUCED, Status.DISTRIBUTED)
        );
        tc.distributeBatch(other, LOC_C);
    }

    // ── registerUser ────────────────────────────────────────────────────

    function test_registerUser_createsUserWithCorrectFields() public {
        // Admin registers alice as PRODUCER
        tc.registerUser(alice, "Alice Producer", Role.PRODUCER);

        User memory u = tc.getUser(alice);
        assertEq(u.ethAddress, alice);
        assertEq(uint8(u.role), uint8(Role.PRODUCER));
        assertTrue(u.isActive);
        assertEq(u.name, "Alice Producer");
        assertGt(u.registeredAt, 0);
    }

    function test_registerUser_emitsEvent() public {
        // Tell Forge to expect this event on the next call
        vm.expectEmit(true, false, false, true);
        emit ITrustChain.UserRegistered(alice, "Alice Producer", Role.PRODUCER);

        tc.registerUser(alice, "Alice Producer", Role.PRODUCER);
    }

    function test_registerUser_revertsWhenCallerNotAdmin() public {
        // alice is not registered, so she has no role
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.registerUser(bob, "Bob", Role.TRANSPORTER);
    }

    function test_registerUser_revertsWhenZeroAddress() public {
        vm.expectRevert(ITrustChain.ZeroAddress.selector);
        tc.registerUser(address(0), "Zero", Role.PRODUCER);
    }

    function test_registerUser_revertsWhenAlreadyRegistered() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        vm.expectRevert(ITrustChain.AlreadyRegistered.selector);
        tc.registerUser(alice, "Alice Again", Role.TRANSPORTER);
    }

    // ── deactivateUser ──────────────────────────────────────────────────

    function test_deactivateUser_setsIsActiveFalse() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        tc.deactivateUser(alice);

        User memory u = tc.getUser(alice);
        assertFalse(u.isActive);
    }

    function test_deactivateUser_emitsEvent() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        vm.expectEmit(true, false, false, false);
        emit ITrustChain.UserDeactivated(alice);

        tc.deactivateUser(alice);
    }

    function test_deactivateUser_revertsWhenCallerNotAdmin() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.deactivateUser(alice);
    }

    function test_deactivateUser_revertsWhenNotRegistered() public {
        vm.expectRevert(ITrustChain.NotRegistered.selector);
        tc.deactivateUser(alice);
    }

    function test_deactivateUser_revertsWhenSelf() public {
        // Admin must not be able to deactivate themselves — would permanently brick the contract
        // since every admin-gated function becomes unreachable and nobody can re-register another admin.
        vm.expectRevert(ITrustChain.SelfDeactivation.selector);
        tc.deactivateUser(admin);
    }

    // ── activateUser ────────────────────────────────────────────────────

    function test_activateUser_setsIsActiveTrue() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        tc.deactivateUser(alice);
        tc.activateUser(alice);

        User memory u = tc.getUser(alice);
        assertTrue(u.isActive);
    }

    function test_activateUser_emitsEvent() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        tc.deactivateUser(alice);

        vm.expectEmit(true, false, false, false);
        emit ITrustChain.UserActivated(alice);

        tc.activateUser(alice);
    }

    function test_activateUser_revertsWhenCallerNotAdmin() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        tc.deactivateUser(alice);

        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.activateUser(alice);
    }

    function test_activateUser_revertsWhenNotRegistered() public {
        // Symmetric coverage with deactivateUser — activating a non-existent user must revert.
        vm.expectRevert(ITrustChain.NotRegistered.selector);
        tc.activateUser(alice);
    }

    // ── Deactivated user blocked ────────────────────────────────────────

    function test_deactivatedUser_cannotCallRoleFunction() public {
        // Register alice as PRODUCER, then deactivate her
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        tc.deactivateUser(alice);

        // Alice tries to create a batch — should revert
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.createBatch("TEST-001", 0, Category.PERISHABLE, 0, 100, "GR", 0);
    }

    // ── Registry domain ────────────────────────────────────────

    function test_addProductType() public {
        string[] memory before = tc.getProductTypes();

        tc.addProductType("DRINKS");

        string[] memory after_ = tc.getProductTypes();

        assertEq(before.length + 1, after_.length);
        assertEq(after_[after_.length - 1], "DRINKS");
    }

    function test_addProductType_emitsEvent() public {
        // Constructor seeds 7 types (ids 0–6), so next id is 7
        vm.expectEmit(true, false, false, true);
        emit ITrustChain.ProductTypeAdded(7, "DRINKS");

        tc.addProductType("DRINKS");
    }

    function test_addProductType_revertsWhenCallerNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.addProductType("DRINKS");
    }

    function test_addProductType_revertsWhenDuplicate() public {
        // "FOOD" is seeded by the constructor — re-adding must revert.
        vm.expectRevert(ITrustChain.DuplicateProductType.selector);
        tc.addProductType("FOOD");
    }

    // ── addUnit ─────────────────────────────────────────────────────────

    function test_addUnit_appendsToRegistry() public {
        string[] memory before = tc.getUnits();

        tc.addUnit("OZ");

        string[] memory after_ = tc.getUnits();
        assertEq(after_.length, before.length + 1);
        assertEq(after_[after_.length - 1], "OZ");
    }

    function test_addUnit_emitsEvent() public {
        // Constructor seeds 7 units (ids 0–6), so next id is 7
        vm.expectEmit(true, false, false, true);
        emit ITrustChain.UnitAdded(7, "OZ");

        tc.addUnit("OZ");
    }

    function test_addUnit_revertsWhenCallerNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.addUnit("OZ");
    }

    function test_addUnit_revertsWhenDuplicate() public {
        // "KG" is seeded by the constructor — re-adding must revert.
        vm.expectRevert(ITrustChain.DuplicateUnit.selector);
        tc.addUnit("KG");
    }

    // ── createBatch ─────────────────────────────────────────────────────

    function test_createBatch_happyPath() public {
        // 1. Admin registers alice as PRODUCER
        tc.registerUser(alice, "Alice Producer", Role.PRODUCER);

        // 2. Alice creates a batch (vm.prank so msg.sender = alice on the next call)
        vm.prank(alice);
        tc.createBatch(
            "OLIVE-GR-001", // serialNumber
            0, // productTypeId — 0 = FOOD (seeded)
            Category.PERISHABLE,
            0, // unitId — 0 = KG (seeded)
            1000, // quantity
            "GR-PEL", // origin
            0 // expiryDate — 0 = no expiry
        );

        // 3. Read back and assert all fields
        Batch memory b = tc.getBatch("OLIVE-GR-001");
        assertEq(b.serialNumber, "OLIVE-GR-001");
        assertEq(b.producer, alice);
        assertEq(b.quantity, 1000);
        assertEq(b.origin, "GR-PEL");
        assertEq(uint8(b.category), uint8(Category.PERISHABLE));
        assertEq(b.productTypeId, 0);
        assertEq(b.unitId, 0);
    }

    function test_createBatch_revertsWhenInvalidProductType() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        vm.prank(alice);
        vm.expectRevert(ITrustChain.InvalidProductType.selector);
        tc.createBatch(
            "BAD-001",
            99, // productTypeId out of range (only 7 seeded: ids 0–6)
            Category.PERISHABLE,
            0,
            1000,
            "GR-PEL",
            0
        );
    }

    function test_createBatch_revertsWhenInvalidUnit() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        vm.prank(alice);
        vm.expectRevert(ITrustChain.InvalidUnit.selector);
        tc.createBatch(
            "BAD-002",
            0,
            Category.PERISHABLE,
            99, // unitId out of range (only 7 seeded: ids 0–6)
            1000,
            "GR-PEL",
            0
        );
    }

    function test_createBatch_emitsEvent() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        // BatchCreated(bytes32 indexed serialNumber, address indexed producer)
        // Both params are indexed → check topic1 and topic2; no data to check
        vm.expectEmit(true, true, false, false);
        emit ITrustChain.BatchCreated("OLIVE-GR-001", alice);

        vm.prank(alice);
        tc.createBatch("OLIVE-GR-001", 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 0);
    }

    function test_createBatch_setsInitialStatus() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        vm.prank(alice);
        tc.createBatch("OLIVE-GR-001", 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 0);

        Batch memory b = tc.getBatch("OLIVE-GR-001");
        assertEq(uint8(b.status), uint8(Status.PRODUCED));
        assertEq(b.currentHolder, alice);
        assertFalse(b.recalled);
        assertFalse(b.certified);
    }

    function test_createBatch_revertsWhenDuplicateSerial() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);

        vm.prank(alice);
        tc.createBatch("OLIVE-GR-001", 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 0);

        // Second call with the same serial should revert
        vm.prank(alice);
        vm.expectRevert(ITrustChain.DuplicateSerial.selector);
        tc.createBatch("OLIVE-GR-001", 1, Category.NON_PERISHABLE, 1, 500, "GR-ATH", 0);
    }

    function test_createBatch_revertsWhenNotProducer() public {
        // alice is not registered — onlyProducer modifier rejects her
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.createBatch("OLIVE-GR-001", 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 0);
    }

    function test_createBatch_revertsWhenSerialZero() public {
        // serialNumber == bytes32(0) would break the "exists" invariant in _requireBatch
        // (a real batch at key 0 appears not-found) and the dedup check (duplicates allowed at 0).
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.prank(alice);
        vm.expectRevert(ITrustChain.InvalidSerialNumber.selector);
        tc.createBatch(bytes32(0), 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 0);
    }

    function test_createBatch_revertsWhenQuantityZero() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.prank(alice);
        vm.expectRevert(ITrustChain.InvalidQuantity.selector);
        tc.createBatch("ZERO-QTY", 0, Category.PERISHABLE, 0, 0, "GR-PEL", 0);
    }

    function test_createBatch_revertsWhenOriginZero() public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.prank(alice);
        vm.expectRevert(ITrustChain.InvalidOrigin.selector);
        tc.createBatch("NO-ORIGIN", 0, Category.PERISHABLE, 0, 1000, bytes32(0), 0);
    }

    function test_createBatch_revertsWhenExpiryInPast() public {
        // expiryDate == 0 means "no expiry" (allowed). Any non-zero value below block.timestamp
        // is nonsensical — producer would be minting an already-expired batch.
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.warp(1000);
        vm.prank(alice);
        vm.expectRevert(ITrustChain.InvalidExpiryDate.selector);
        tc.createBatch("PAST-EXP", 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 500);
    }

    function test_createBatch_allowsZeroExpiry() public {
        // Documented meaning: expiryDate == 0 = non-perishable, no expiry enforced.
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.warp(1000);
        vm.prank(alice);
        tc.createBatch("NO-EXP", 0, Category.NON_PERISHABLE, 0, 1000, "GR-PEL", 0);
        assertEq(tc.getBatch("NO-EXP").expiryDate, 0);
    }

    function test_createBatch_allowsExpiryAtExactTimestamp() public {
        // Boundary: the guard is `expiryDate < block.timestamp`, so equality is allowed.
        // Pins the edge so a future refactor flipping `<` to `<=` fails loudly.
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.warp(1000);
        vm.prank(alice);
        tc.createBatch("EXP-NOW", 0, Category.PERISHABLE, 0, 1000, "GR-PEL", 1000);
        assertEq(tc.getBatch("EXP-NOW").expiryDate, 1000);
    }

    function test_batchesAreIsolated() public {
        // Transitioning one batch must not affect another — guards against accidental
        // shared storage (e.g. writing to the wrong key during a refactor).
        _registerAll(); // creates SERIAL in PRODUCED, holder=alice

        bytes32 other = "BATCH-002";
        vm.prank(alice);
        tc.createBatch(other, 1, Category.NON_PERISHABLE, 1, 500, "GR-ATH", 0);

        _handoff(SERIAL, alice, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);

        Batch memory b1 = tc.getBatch(SERIAL);
        Batch memory b2 = tc.getBatch(other);
        assertEq(uint8(b1.status), uint8(Status.STORED));
        assertEq(b1.currentHolder, charlie);
        assertEq(uint8(b2.status), uint8(Status.PRODUCED));
        assertEq(b2.currentHolder, alice);
        assertEq(b2.quantity, 500);
    }

    // ── receiveBatch ─────────────────────────────────────────────────────

    function test_receiveBatch_producedToStored() public {
        _registerAll();
        _handoff(SERIAL, alice, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);

        Batch memory b = tc.getBatch(SERIAL);
        assertEq(uint8(b.status), uint8(Status.STORED));
    }

    function test_receiveBatch_inTransitToStored() public {
        _toInTransit(); // bob is currentHolder
        _handoff(SERIAL, bob, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);

        Batch memory b = tc.getBatch(SERIAL);
        assertEq(uint8(b.status), uint8(Status.STORED));
    }

    function test_receiveBatch_recalledToStored() public {
        _toDistributed();
        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C); // auditor is now currentHolder
        _handoff(SERIAL, auditor, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);

        Batch memory b = tc.getBatch(SERIAL);
        assertEq(uint8(b.status), uint8(Status.STORED));
    }

    function test_receiveBatch_updatesCurrentHolder() public {
        _registerAll();
        _handoff(SERIAL, alice, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);

        assertEq(tc.getBatch(SERIAL).currentHolder, charlie);
    }

    function test_receiveBatch_emitsEvent() public {
        _registerAll();
        _handoff(SERIAL, alice, charlie);

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.BatchTransitioned(SERIAL, Status.PRODUCED, Status.STORED, LOC_A, charlie, 0);

        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);
    }

    function test_receiveBatch_revertsWhenNotCurrentHolder() public {
        _registerAll(); // currentHolder = alice (PRODUCER)
        vm.prank(charlie); // charlie is WAREHOUSE but not currentHolder
        vm.expectRevert(ITrustChain.NotCurrentHolder.selector);
        tc.receiveBatch(SERIAL, LOC_A);
    }

    function test_receiveBatch_revertsWhenBatchNotFound() public {
        _registerAll();
        vm.prank(charlie);
        vm.expectRevert(ITrustChain.BatchNotFound.selector);
        tc.receiveBatch("NO-SUCH-BATCH", LOC_A);
    }

    function test_receiveBatch_revertsWhenUnauthorized() public {
        _registerAll();
        vm.prank(alice); // alice is PRODUCER, not WAREHOUSE
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.receiveBatch(SERIAL, LOC_A);
    }

    function test_receiveBatch_revertsOnInvalidTransition() public {
        // DISTRIBUTED → STORED is not in the allowed matrix
        _toDistributed(); // distributor is currentHolder
        _handoff(SERIAL, distributor, charlie); // charlie needs custody so custody check passes
        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustChain.InvalidTransition.selector, Status.DISTRIBUTED, Status.STORED)
        );
        tc.receiveBatch(SERIAL, LOC_A);
    }

    // ── shipBatch ────────────────────────────────────────────────────────

    function test_shipBatch_producedToInTransit() public {
        _registerAll();
        _handoff(SERIAL, alice, bob);
        vm.prank(bob);
        tc.shipBatch(SERIAL, LOC_B);

        assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.IN_TRANSIT));
    }

    function test_shipBatch_storedToInTransit() public {
        _toStored(); // charlie is currentHolder
        _handoff(SERIAL, charlie, bob);
        vm.prank(bob);
        tc.shipBatch(SERIAL, LOC_B);

        assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.IN_TRANSIT));
    }

    function test_shipBatch_updatesCurrentHolder() public {
        _registerAll();
        _handoff(SERIAL, alice, bob);
        vm.prank(bob);
        tc.shipBatch(SERIAL, LOC_B);

        assertEq(tc.getBatch(SERIAL).currentHolder, bob);
    }

    function test_shipBatch_emitsEvent() public {
        _registerAll();
        _handoff(SERIAL, alice, bob);

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.BatchTransitioned(SERIAL, Status.PRODUCED, Status.IN_TRANSIT, LOC_B, bob, 0);

        vm.prank(bob);
        tc.shipBatch(SERIAL, LOC_B);
    }

    function test_shipBatch_revertsWhenNotCurrentHolder() public {
        _registerAll(); // currentHolder = alice (PRODUCER)
        vm.prank(bob); // bob is TRANSPORTER but not currentHolder
        vm.expectRevert(ITrustChain.NotCurrentHolder.selector);
        tc.shipBatch(SERIAL, LOC_B);
    }

    function test_shipBatch_revertsWhenBatchNotFound() public {
        _registerAll();
        vm.prank(bob);
        vm.expectRevert(ITrustChain.BatchNotFound.selector);
        tc.shipBatch("NO-SUCH-BATCH", LOC_B);
    }

    function test_shipBatch_revertsWhenUnauthorized() public {
        _registerAll();
        vm.prank(alice); // alice is PRODUCER, not TRANSPORTER
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.shipBatch(SERIAL, LOC_B);
    }

    function test_shipBatch_revertsOnInvalidTransition() public {
        // DISTRIBUTED → IN_TRANSIT is not allowed
        _toDistributed(); // distributor is currentHolder
        _handoff(SERIAL, distributor, bob); // bob needs custody so custody check passes
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustChain.InvalidTransition.selector, Status.DISTRIBUTED, Status.IN_TRANSIT)
        );
        tc.shipBatch(SERIAL, LOC_B);
    }

    // ── distributeBatch ──────────────────────────────────────────────────

    function test_distributeBatch_storedToDistributed() public {
        _toStored(); // charlie is currentHolder
        _handoff(SERIAL, charlie, distributor);
        vm.prank(distributor);
        tc.distributeBatch(SERIAL, LOC_C);

        assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.DISTRIBUTED));
    }

    function test_distributeBatch_inTransitToDistributed() public {
        _toInTransit(); // bob is currentHolder
        _handoff(SERIAL, bob, distributor);
        vm.prank(distributor);
        tc.distributeBatch(SERIAL, LOC_C);

        assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.DISTRIBUTED));
    }

    function test_distributeBatch_updatesCurrentHolder() public {
        _toStored(); // charlie is currentHolder
        _handoff(SERIAL, charlie, distributor);
        vm.prank(distributor);
        tc.distributeBatch(SERIAL, LOC_C);

        assertEq(tc.getBatch(SERIAL).currentHolder, distributor);
    }

    function test_distributeBatch_emitsEvent() public {
        _toStored(); // charlie is currentHolder
        _handoff(SERIAL, charlie, distributor);

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.BatchTransitioned(SERIAL, Status.STORED, Status.DISTRIBUTED, LOC_C, distributor, 0);

        vm.prank(distributor);
        tc.distributeBatch(SERIAL, LOC_C);
    }

    function test_distributeBatch_revertsWhenNotCurrentHolder() public {
        _toStored(); // charlie is currentHolder
        vm.prank(distributor); // distributor is DISTRIBUTOR but not currentHolder
        vm.expectRevert(ITrustChain.NotCurrentHolder.selector);
        tc.distributeBatch(SERIAL, LOC_C);
    }

    function test_distributeBatch_revertsWhenBatchNotFound() public {
        _registerAll();
        vm.prank(distributor);
        vm.expectRevert(ITrustChain.BatchNotFound.selector);
        tc.distributeBatch("NO-SUCH-BATCH", LOC_C);
    }

    function test_distributeBatch_revertsWhenUnauthorized() public {
        _toStored();
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.distributeBatch(SERIAL, LOC_C);
    }

    function test_distributeBatch_revertsOnInvalidTransition() public {
        // PRODUCED → DISTRIBUTED is not allowed
        _registerAll(); // alice is currentHolder
        _handoff(SERIAL, alice, distributor); // distributor needs custody so custody check passes
        vm.prank(distributor);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustChain.InvalidTransition.selector, Status.PRODUCED, Status.DISTRIBUTED)
        );
        tc.distributeBatch(SERIAL, LOC_C);
    }

    function test_distributeBatch_revertsWhenRecalled() public {
        // A batch that has been recalled must not be distributable.
        // The `recalled` guard fires before the custody check.
        _toDistributed();
        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C); // auditor is now currentHolder

        // Re-store it so the transition would otherwise be valid
        _handoff(SERIAL, auditor, charlie);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A); // charlie is now currentHolder, status=STORED

        // recalled guard fires first — custody check is irrelevant
        vm.prank(distributor);
        vm.expectRevert(ITrustChain.CannotDistributeRecalled.selector);
        tc.distributeBatch(SERIAL, LOC_C);
    }

    // ── recallBatch ──────────────────────────────────────────────────────

    function test_recallBatch_distributedToRecalled() public {
        _toDistributed();
        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C);

        assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.RECALLED));
    }

    function test_recallBatch_setsRecalledFlag() public {
        _toDistributed();
        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C);

        assertTrue(tc.getBatch(SERIAL).recalled);
    }

    function test_recallBatch_emitsBatchRecalled() public {
        _toDistributed();

        vm.expectEmit(true, true, false, false);
        emit ITrustChain.BatchRecalled(SERIAL, auditor);

        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C);
    }

    function test_recallBatch_emitsBatchTransitioned() public {
        _toDistributed();

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.BatchTransitioned(SERIAL, Status.DISTRIBUTED, Status.RECALLED, LOC_C, auditor, 0);

        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C);
    }

    function test_recallBatch_revertsWhenBatchNotFound() public {
        _registerAll();
        vm.prank(auditor);
        vm.expectRevert(ITrustChain.BatchNotFound.selector);
        tc.recallBatch("NO-SUCH-BATCH", LOC_C);
    }

    function test_recallBatch_revertsWhenUnauthorized() public {
        _toDistributed();
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.recallBatch(SERIAL, LOC_C);
    }

    function test_recallBatch_revertsOnInvalidTransition() public {
        // DISPOSED → RECALLED is not allowed — DISPOSED is the terminal state.
        _toRecalledStored();
        vm.prank(charlie);
        tc.disposeBatch(SERIAL, LOC_A);

        vm.prank(auditor);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustChain.InvalidTransition.selector, Status.DISPOSED, Status.RECALLED)
        );
        tc.recallBatch(SERIAL, LOC_C);
    }

    // ── certifyBatch ─────────────────────────────────────────────────────

    function test_certifyBatch_setsCertifiedFlag() public {
        _toDistributed();
        vm.prank(auditor);
        tc.certifyBatch(SERIAL);

        assertTrue(tc.getBatch(SERIAL).certified);
    }

    function test_certifyBatch_emitsEvent() public {
        _toDistributed();

        vm.expectEmit(true, true, false, false);
        emit ITrustChain.BatchCertified(SERIAL, auditor);

        vm.prank(auditor);
        tc.certifyBatch(SERIAL);
    }

    function test_certifyBatch_revertsWhenBatchNotFound() public {
        _registerAll();
        vm.prank(auditor);
        vm.expectRevert(ITrustChain.BatchNotFound.selector);
        tc.certifyBatch("NO-SUCH-BATCH");
    }

    function test_certifyBatch_revertsWhenUnauthorized() public {
        _toDistributed();
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.certifyBatch(SERIAL);
    }

    function test_certifyBatch_revertsWhenAlreadyCertified() public {
        // Idempotency: certifying twice should revert rather than re-emit the event.
        _toDistributed();
        vm.prank(auditor);
        tc.certifyBatch(SERIAL);

        vm.prank(auditor);
        vm.expectRevert(ITrustChain.AlreadyCertified.selector);
        tc.certifyBatch(SERIAL);
    }

    function test_certifyBatch_revertsWhenNotDistributed() public {
        // Certification only valid post-distribution; PRODUCED must revert.
        _registerAll();
        vm.prank(auditor);
        vm.expectRevert(abi.encodeWithSelector(ITrustChain.CannotCertifyInStatus.selector, Status.PRODUCED));
        tc.certifyBatch(SERIAL);
    }

    function test_certifyBatch_revertsWhenRecalled() public {
        // A recalled batch is compromised — it must not be certifiable after the fact.
        _toDistributed();
        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C);

        vm.prank(auditor);
        vm.expectRevert(abi.encodeWithSelector(ITrustChain.CannotCertifyInStatus.selector, Status.RECALLED));
        tc.certifyBatch(SERIAL);
    }

    function test_certifyBatch_revertsWhenDisposed() public {
        // A disposed batch is terminal reverse-logistics — certification is meaningless.
        _toRecalledStored();
        vm.prank(charlie);
        tc.disposeBatch(SERIAL, LOC_A);

        vm.prank(auditor);
        vm.expectRevert(abi.encodeWithSelector(ITrustChain.CannotCertifyInStatus.selector, Status.DISPOSED));
        tc.certifyBatch(SERIAL);
    }

    // ── disposeBatch ─────────────────────────────────────────────────────

    function test_disposeBatch_recalledStoredToDisposed() public {
        _toRecalledStored();
        vm.prank(charlie);
        tc.disposeBatch(SERIAL, LOC_A);

        assertEq(uint8(tc.getBatch(SERIAL).status), uint8(Status.DISPOSED));
    }

    function test_disposeBatch_emitsEvent() public {
        _toRecalledStored();

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.BatchTransitioned(SERIAL, Status.STORED, Status.DISPOSED, LOC_A, charlie, 0);

        vm.prank(charlie);
        tc.disposeBatch(SERIAL, LOC_A);
    }

    function test_disposeBatch_revertsWhenNotRecalled() public {
        // A plain STORED batch (never recalled) must NOT be disposable.
        // disposeBatch is reverse-logistics only — normal goods cannot be binned.
        _toStored();
        vm.prank(charlie);
        vm.expectRevert(ITrustChain.BatchNotRecalled.selector);
        tc.disposeBatch(SERIAL, LOC_A);
    }

    function test_disposeBatch_revertsWhenBatchNotFound() public {
        _registerAll();
        vm.prank(charlie);
        vm.expectRevert(ITrustChain.BatchNotFound.selector);
        tc.disposeBatch("NO-SUCH-BATCH", LOC_A);
    }

    function test_disposeBatch_revertsWhenUnauthorized() public {
        _toStored();
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.disposeBatch(SERIAL, LOC_A);
    }

    function test_disposeBatch_revertsWhenNotCurrentHolder() public {
        _toRecalledStored(); // charlie is currentHolder, status=STORED, recalled=true
        // Register a second warehouse and try to dispose without custody
        address warehouse2 = makeAddr("Warehouse2");
        tc.registerUser(warehouse2, "Warehouse2", Role.WAREHOUSE);
        vm.prank(warehouse2);
        vm.expectRevert(ITrustChain.NotCurrentHolder.selector);
        tc.disposeBatch(SERIAL, LOC_A);
    }

    function test_disposeBatch_revertsOnInvalidTransition() public {
        // A recalled batch still in RECALLED (not yet received to STORED)
        // passes the recalled gate but fails the matrix: RECALLED → DISPOSED is not allowed.
        _toDistributed();
        vm.prank(auditor);
        tc.recallBatch(SERIAL, LOC_C); // auditor is now currentHolder, status=RECALLED
        // give charlie custody so the custody check passes and the matrix check fires
        _handoff(SERIAL, auditor, charlie);
        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(ITrustChain.InvalidTransition.selector, Status.RECALLED, Status.DISPOSED)
        );
        tc.disposeBatch(SERIAL, LOC_A);
    }

    // ── proposeCustody / acceptCustody / cancelCustody ──────────────────────

    function test_custody_proposeDoesNotMoveHolderUntilAccepted() public {
        _registerAll(); // alice is currentHolder
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);

        // Custody has NOT moved yet — alice is still holder, bob is only pending.
        assertEq(tc.getBatch(SERIAL).currentHolder, alice);
        assertEq(tc.pendingHolder(SERIAL), bob);
    }

    function test_custody_acceptMovesHolder() public {
        _registerAll();
        _handoff(SERIAL, alice, bob);
        assertEq(tc.getBatch(SERIAL).currentHolder, bob);
        // Pending is cleared after accept.
        assertEq(tc.pendingHolder(SERIAL), address(0));
    }

    function test_proposeCustody_emitsEvent() public {
        _registerAll();
        vm.expectEmit(true, true, true, false);
        emit ITrustChain.CustodyProposed(SERIAL, alice, bob);
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);
    }

    function test_acceptCustody_emitsCustodyTransferred() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.CustodyTransferred(SERIAL, alice, bob);
        vm.prank(bob);
        tc.acceptCustody(SERIAL);
    }

    function test_proposeCustody_revertsWhenNotCurrentHolder() public {
        _registerAll(); // currentHolder = alice
        vm.prank(bob); // bob is not the holder
        vm.expectRevert(ITrustChain.NotCurrentHolder.selector);
        tc.proposeCustody(SERIAL, charlie);
    }

    function test_proposeCustody_revertsWhenBatchNotFound() public {
        _registerAll();
        vm.prank(alice);
        vm.expectRevert(ITrustChain.BatchNotFound.selector);
        tc.proposeCustody("NO-SUCH-BATCH", bob);
    }

    function test_proposeCustody_revertsWhenZeroAddress() public {
        _registerAll();
        vm.prank(alice);
        vm.expectRevert(ITrustChain.ZeroAddress.selector);
        tc.proposeCustody(SERIAL, address(0));
    }

    function test_proposeCustody_revertsWhenRecipientInactive() public {
        _registerAll();
        tc.deactivateUser(bob);
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.proposeCustody(SERIAL, bob);
    }

    function test_proposeCustody_revertsWhenProposerDeactivated() public {
        // Regression: a deactivated holder must NOT be able to offload a batch they hold.
        _registerAll(); // alice (PRODUCER) holds SERIAL
        tc.deactivateUser(alice);
        vm.prank(alice);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.proposeCustody(SERIAL, bob);
    }

    function test_acceptCustody_revertsWhenNoPending() public {
        _registerAll();
        vm.prank(bob);
        vm.expectRevert(ITrustChain.NoPendingCustody.selector);
        tc.acceptCustody(SERIAL);
    }

    function test_acceptCustody_revertsWhenNotPendingHolder() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);
        // charlie is not the proposed recipient
        vm.prank(charlie);
        vm.expectRevert(ITrustChain.NotPendingHolder.selector);
        tc.acceptCustody(SERIAL);
    }

    function test_acceptCustody_revertsWhenAccepterDeactivated() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);
        tc.deactivateUser(bob);
        vm.prank(bob);
        vm.expectRevert(ITrustChain.Unauthorized.selector);
        tc.acceptCustody(SERIAL);
    }

    function test_cancelCustody_clearsPendingOffer() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);
        vm.prank(alice);
        tc.cancelCustody(SERIAL);

        assertEq(tc.pendingHolder(SERIAL), address(0));
        // A subsequent accept now reverts — the offer is gone.
        vm.prank(bob);
        vm.expectRevert(ITrustChain.NoPendingCustody.selector);
        tc.acceptCustody(SERIAL);
    }

    function test_cancelCustody_emitsEvent() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.CustodyCancelled(SERIAL, alice, bob);
        vm.prank(alice);
        tc.cancelCustody(SERIAL);
    }

    function test_cancelCustody_revertsWhenNoPending() public {
        _registerAll();
        vm.prank(alice);
        vm.expectRevert(ITrustChain.NoPendingCustody.selector);
        tc.cancelCustody(SERIAL);
    }

    function test_cancelCustody_revertsWhenNotCurrentHolder() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);
        vm.prank(charlie); // not the holder
        vm.expectRevert(ITrustChain.NotCurrentHolder.selector);
        tc.cancelCustody(SERIAL);
    }

    function test_declineCustody_clearsPendingAndKeepsHolder() public {
        _registerAll(); // alice holds SERIAL
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);
        vm.prank(bob);
        tc.declineCustody(SERIAL);

        assertEq(tc.pendingHolder(SERIAL), address(0));
        assertEq(tc.getBatch(SERIAL).currentHolder, alice); // custody stays with the holder
    }

    function test_declineCustody_emitsEvent() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);

        vm.expectEmit(true, true, true, false);
        emit ITrustChain.CustodyDeclined(SERIAL, alice, bob);
        vm.prank(bob);
        tc.declineCustody(SERIAL);
    }

    function test_declineCustody_revertsWhenNoPending() public {
        _registerAll();
        vm.prank(bob);
        vm.expectRevert(ITrustChain.NoPendingCustody.selector);
        tc.declineCustody(SERIAL);
    }

    function test_declineCustody_revertsWhenNotPendingHolder() public {
        _registerAll();
        vm.prank(alice);
        tc.proposeCustody(SERIAL, bob);
        vm.prank(charlie); // not the proposed recipient
        vm.expectRevert(ITrustChain.NotPendingHolder.selector);
        tc.declineCustody(SERIAL);
    }

    function test_transition_clearsStalePendingOffer() public {
        // A status change must invalidate a pending offer made under the previous state.
        _registerAll(); // alice holds SERIAL in PRODUCED
        _handoff(SERIAL, alice, charlie); // charlie (WAREHOUSE) now holds it
        // charlie offers custody to bob, then receives the batch (PRODUCED → STORED)
        vm.prank(charlie);
        tc.proposeCustody(SERIAL, bob);
        vm.prank(charlie);
        tc.receiveBatch(SERIAL, LOC_A);

        // The transition cleared the stale offer; bob can no longer accept.
        assertEq(tc.pendingHolder(SERIAL), address(0));
        vm.prank(bob);
        vm.expectRevert(ITrustChain.NoPendingCustody.selector);
        tc.acceptCustody(SERIAL);
    }

    // ── BatchExpired ──────────────────────────────────────────────────────

    function test_transition_revertsWhenBatchExpired() public {
        _registerAll();
        vm.warp(1000);
        vm.prank(alice);
        tc.createBatch("EXP-BATCH", 0, Category.PERISHABLE, 0, 100, "GR-PEL", 2000);

        _handoff("EXP-BATCH", alice, charlie);
        vm.warp(2001); // past expiry

        vm.prank(charlie);
        vm.expectRevert(ITrustChain.BatchExpired.selector);
        tc.receiveBatch("EXP-BATCH", LOC_A);
    }

    function test_transition_allowsTransitionBeforeExpiry() public {
        _registerAll();
        vm.warp(1000);
        vm.prank(alice);
        tc.createBatch("EXP-BATCH", 0, Category.PERISHABLE, 0, 100, "GR-PEL", 2000);

        _handoff("EXP-BATCH", alice, charlie);
        vm.warp(1999); // still before expiry

        vm.prank(charlie);
        tc.receiveBatch("EXP-BATCH", LOC_A);
        assertEq(uint8(tc.getBatch("EXP-BATCH").status), uint8(Status.STORED));
    }

    function test_expiredBatch_canBeRecalled() public {
        // An expired batch must still be recallable — that is the whole point of the
        // recall mechanism for food/pharma products.
        _registerAll();
        vm.warp(1000);
        vm.prank(alice);
        tc.createBatch("EXP-BATCH", 0, Category.PERISHABLE, 0, 100, "GR-PEL", 2000);

        _handoff("EXP-BATCH", alice, charlie);
        vm.prank(charlie);
        tc.receiveBatch("EXP-BATCH", LOC_A); // STORED before expiry
        _handoff("EXP-BATCH", charlie, distributor);
        vm.prank(distributor);
        tc.distributeBatch("EXP-BATCH", LOC_C); // DISTRIBUTED before expiry

        vm.warp(2001); // now expired

        // Recall must succeed on an expired batch
        vm.prank(auditor);
        tc.recallBatch("EXP-BATCH", LOC_C);
        assertEq(uint8(tc.getBatch("EXP-BATCH").status), uint8(Status.RECALLED));
        assertTrue(tc.getBatch("EXP-BATCH").recalled);

        // Dispose must also succeed
        _handoff("EXP-BATCH", auditor, charlie);
        vm.prank(charlie);
        tc.receiveBatch("EXP-BATCH", LOC_A); // RECALLED → STORED
        vm.prank(charlie);
        tc.disposeBatch("EXP-BATCH", LOC_A);
        assertEq(uint8(tc.getBatch("EXP-BATCH").status), uint8(Status.DISPOSED));
    }
}
