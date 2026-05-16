// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TrustChainTestBase} from "./TrustChainTestBase.t.sol";
import {ITrustChain} from "../src/ITrustChain.sol";
import {Role, Category} from "../src/DataTypes.sol";

/// @notice Property / fuzz tests for TrustChain.
/// @dev Each testFuzz_* runs ~256 times by default with random inputs.
/// Tune runs in foundry.toml under `[fuzz]`. Failing inputs are persisted to
/// `cache/fuzz/` and replayed on subsequent runs.
contract TrustChainFuzzTest is TrustChainTestBase {
    /// Property: any non-zero uint128 quantity must be stored byte-for-byte.
    /// Catches truncation, packing, and type-cast bugs across the full uint128 range.
    function testFuzz_createBatch_storesQuantityExactly(uint128 quantity) public {
        vm.assume(quantity > 0);
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.prank(alice);
        tc.createBatch("FUZZ-Q", 0, Category.PERISHABLE, 0, quantity, "GR-PEL", 0);
        assertEq(tc.getBatch("FUZZ-Q").quantity, quantity);
    }

    /// Property: expiryDate < block.timestamp reverts (except 0);
    ///           expiryDate == 0 or >= block.timestamp succeeds.
    /// Explores the full uint48 space (~281 trillion values) — impossible by hand.
    function testFuzz_createBatch_expiryBoundary(uint48 expiryDate) public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        vm.warp(1000);
        vm.prank(alice);
        if (expiryDate != 0 && expiryDate < 1000) {
            vm.expectRevert(ITrustChain.InvalidExpiryDate.selector);
        }
        tc.createBatch("FUZZ-EX", 0, Category.PERISHABLE, 0, 100, "GR-PEL", expiryDate);
    }

    /// Property: productTypeId < productTypeCount succeeds; anything else reverts.
    /// @dev The `count` is cached BEFORE `vm.prank(alice)` — `vm.prank` applies
    /// to exactly one subsequent external call, and `tc.productTypeCount()` is
    /// a call. Reading it after the prank would consume the spoofed sender and
    /// `createBatch` would run as admin, reverting with `Unauthorized` instead.
    function testFuzz_createBatch_productTypeIdBoundary(uint8 productTypeId) public {
        tc.registerUser(alice, "Alice", Role.PRODUCER);
        uint8 count = tc.productTypeCount();
        vm.prank(alice);
        if (productTypeId >= count) {
            vm.expectRevert(ITrustChain.InvalidProductType.selector);
        }
        tc.createBatch("FUZZ-PT", productTypeId, Category.OTHER, 0, 100, "GR-PEL", 0);
    }
}
