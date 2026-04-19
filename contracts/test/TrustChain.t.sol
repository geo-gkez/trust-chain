// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {TrustChain} from "../src/TrustChain.sol";
import {ITrustChain} from "../src/ITrustChain.sol";
import {Role, Status, Category, User, Batch} from "../src/DataTypes.sol";

contract TrustChainTest is Test {
    TrustChain tc;

    // The test contract deploys TrustChain, so address(this) = ADMIN
    address admin = address(this);

    // makeAddr generates a deterministic address from a label
    // Labels show up in test traces — easier to debug than address(0x1)
    address alice = makeAddr("Alice");
    address bob = makeAddr("Bob");
    address charlie = makeAddr("Charlie");

    /// @notice Deploy a fresh contract before every test
    function setUp() public {
        tc = new TrustChain();
    }

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

    function test_constructor_seedsTransitionMatrix() public view {
        // Valid transitions
        assertTrue(tc.allowedTransitions(Status.PRODUCED, Status.STORED));
        assertTrue(tc.allowedTransitions(Status.PRODUCED, Status.IN_TRANSIT));
        assertTrue(tc.allowedTransitions(Status.DISTRIBUTED, Status.RECALLED));

        // Invalid transitions
        assertFalse(tc.allowedTransitions(Status.PRODUCED, Status.DISTRIBUTED));
        assertFalse(tc.allowedTransitions(Status.DISPOSED, Status.STORED));
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
}
