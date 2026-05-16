// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {TrustChain} from "../src/TrustChain.sol";
import {Role, Category} from "../src/DataTypes.sol";

/// @notice Deploys TrustChain and seeds it with 10 batches and 2 complete routes.
///
/// Usage (against a local Anvil node):
///   anvil                          # terminal 1 — starts at http://localhost:8545
///   forge script script/Deploy.s.sol \
///     --rpc-url http://localhost:8545 \
///     --broadcast                  # terminal 2
///
/// The script uses Anvil's well-known default accounts so no --private-key flag is needed.
contract Deploy is Script {
    // ── Anvil default accounts (accounts 0-5) ────────────────────────────
    uint256 constant ADMIN_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant PRODUCER_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 constant TRANSPORTER_KEY = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 constant WAREHOUSE_KEY = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    uint256 constant DISTRIBUTOR_KEY = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;
    uint256 constant AUDITOR_KEY = 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba;

    address constant PRODUCER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant TRANSPORTER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address constant WAREHOUSE = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address constant DISTRIBUTOR = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address constant AUDITOR = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;

    TrustChain tc;

    function run() external returns (TrustChain) {
        _deploy();
        _createBatches();
        _route1_oliveOil();
        _route2_pharmaRecall();
        _partialStates();
        _printSummary();
        return tc;
    }

    // ── 1. Deploy + register users ────────────────────────────────────────

    function _deploy() internal {
        vm.startBroadcast(ADMIN_KEY);
        tc = new TrustChain();
        tc.registerUser(PRODUCER, "Nikos Papadopoulos", Role.PRODUCER);
        tc.registerUser(TRANSPORTER, "Kostas Logistics", Role.TRANSPORTER);
        tc.registerUser(WAREHOUSE, "Athens Warehouse", Role.WAREHOUSE);
        tc.registerUser(DISTRIBUTOR, "Hellas Dist", Role.DISTRIBUTOR);
        tc.registerUser(AUDITOR, "EFET Inspector", Role.AUDITOR);
        vm.stopBroadcast();
    }

    // ── 2. Create all 10 batches ──────────────────────────────────────────
    //
    // Final states after the full script:
    //   OLIVE-GR-001   FOOD        PERISHABLE    → DISTRIBUTED + certified  (Route 1)
    //   PHARMA-GR-001  PHARMA      REFRIGERATED  → DISPOSED (recalled)      (Route 2)
    //   WINE-GR-001    FOOD        NON_PERISHABLE→ STORED
    //   HONEY-GR-001   FOOD        NON_PERISHABLE→ STORED
    //   VACCINE-GR-001 PHARMA      REFRIGERATED  → STORED
    //   AGRI-GR-001    AGRICULTURE PERISHABLE    → IN_TRANSIT
    //   STEEL-GR-001   INDUSTRIAL  NON_PERISHABLE→ DISTRIBUTED + certified
    //   ELEC-GR-001    ELECTRONICS FRAGILE       → PRODUCED
    //   TEXT-GR-001    TEXTILE     NON_PERISHABLE→ PRODUCED
    //   CHEM-GR-001    CHEMICAL    HAZARDOUS     → PRODUCED

    function _createBatches() internal {
        uint48 d30 = uint48(block.timestamp + 30 days);
        uint48 d180 = uint48(block.timestamp + 180 days);
        uint48 d365 = uint48(block.timestamp + 365 days);
        uint48 d730 = uint48(block.timestamp + 730 days);

        vm.startBroadcast(PRODUCER_KEY);

        // Seeded product type IDs: 0=FOOD 1=PHARMA 2=INDUSTRIAL 3=ELECTRONICS
        //                          4=AGRICULTURE 5=CHEMICAL 6=TEXTILE
        // Seeded unit IDs:         0=KG 1=G 2=TON 3=L 4=ML 5=PCS 6=M2

        tc.createBatch("OLIVE-GR-001", 0, Category.PERISHABLE, 0, 5000, "GR-PEL", d180);
        tc.createBatch("PHARMA-GR-001", 1, Category.REFRIGERATED, 5, 500, "GR-ATH", d365);
        tc.createBatch("WINE-GR-001", 0, Category.NON_PERISHABLE, 3, 10000, "GR-PEL", 0);
        tc.createBatch("HONEY-GR-001", 0, Category.NON_PERISHABLE, 0, 3000, "GR-PEL", d730);
        tc.createBatch("VACCINE-GR-001", 1, Category.REFRIGERATED, 5, 200, "GR-ATH", d180);
        tc.createBatch("AGRI-GR-001", 4, Category.PERISHABLE, 2, 100, "GR-PEL", d30);
        tc.createBatch("STEEL-GR-001", 2, Category.NON_PERISHABLE, 2, 50, "GR-PIR", 0);
        tc.createBatch("ELEC-GR-001", 3, Category.FRAGILE, 5, 500, "GR-PIR", 0);
        tc.createBatch("TEXT-GR-001", 6, Category.NON_PERISHABLE, 6, 5000, "GR-ATH", 0);
        tc.createBatch("CHEM-GR-001", 5, Category.HAZARDOUS, 3, 2000, "GR-PIR", 0);

        vm.stopBroadcast();
    }

    // ── Route 1: Olive oil — complete forward chain, auditor-certified ────
    //
    //   PRODUCED
    //     → STORED    (WH-KALAMATA — origin warehouse)
    //     → IN_TRANSIT(TRUCK-001   — first leg)
    //     → STORED    (WH-ATHENS   — hub warehouse)
    //     → IN_TRANSIT(TRUCK-002   — final leg)
    //     → DISTRIBUTED (DIST-PIR)
    //     → certified

    function _route1_oliveOil() internal {
        bytes32 s = "OLIVE-GR-001";

        vm.startBroadcast(PRODUCER_KEY);
        tc.transferCustody(s, WAREHOUSE);
        vm.stopBroadcast();

        vm.startBroadcast(WAREHOUSE_KEY);
        tc.receiveBatch(s, "WH-KALAMATA");
        tc.transferCustody(s, TRANSPORTER);
        vm.stopBroadcast();

        vm.startBroadcast(TRANSPORTER_KEY);
        tc.shipBatch(s, "TRUCK-001");
        tc.transferCustody(s, WAREHOUSE);
        vm.stopBroadcast();

        vm.startBroadcast(WAREHOUSE_KEY);
        tc.receiveBatch(s, "WH-ATHENS");
        tc.transferCustody(s, TRANSPORTER);
        vm.stopBroadcast();

        vm.startBroadcast(TRANSPORTER_KEY);
        tc.shipBatch(s, "TRUCK-002");
        tc.transferCustody(s, DISTRIBUTOR);
        vm.stopBroadcast();

        vm.startBroadcast(DISTRIBUTOR_KEY);
        tc.distributeBatch(s, "DIST-PIR");
        vm.stopBroadcast();

        vm.startBroadcast(AUDITOR_KEY);
        tc.certifyBatch(s);
        vm.stopBroadcast();
    }

    // ── Route 2: Pharma — contamination recall + quarantine disposal ──────
    //
    //   PRODUCED
    //     → STORED    (WH-ATHENS)
    //     → IN_TRANSIT(TRUCK-PHARMA)
    //     → DISTRIBUTED (DIST-ATH)
    //     → RECALLED  (contamination found)
    //     → STORED    (WH-QUARANTINE — auditor designates warehouse)
    //     → DISPOSED

    function _route2_pharmaRecall() internal {
        bytes32 s = "PHARMA-GR-001";

        vm.startBroadcast(PRODUCER_KEY);
        tc.transferCustody(s, WAREHOUSE);
        vm.stopBroadcast();

        vm.startBroadcast(WAREHOUSE_KEY);
        tc.receiveBatch(s, "WH-ATHENS");
        tc.transferCustody(s, TRANSPORTER);
        vm.stopBroadcast();

        vm.startBroadcast(TRANSPORTER_KEY);
        tc.shipBatch(s, "TRUCK-PHARMA");
        tc.transferCustody(s, DISTRIBUTOR);
        vm.stopBroadcast();

        vm.startBroadcast(DISTRIBUTOR_KEY);
        tc.distributeBatch(s, "DIST-ATH");
        vm.stopBroadcast();

        // Auditor recalls and designates warehouse for quarantine
        vm.startBroadcast(AUDITOR_KEY);
        tc.recallBatch(s, "DIST-ATH");
        tc.transferCustody(s, WAREHOUSE);
        vm.stopBroadcast();

        vm.startBroadcast(WAREHOUSE_KEY);
        tc.receiveBatch(s, "WH-QUARANTINE");
        tc.disposeBatch(s, "WH-QUARANTINE");
        vm.stopBroadcast();
    }

    // ── Partial lifecycle states for remaining 8 batches ─────────────────

    function _partialStates() internal {
        // WINE, HONEY, VACCINE → STORED at Athens warehouse
        _storeAt("WINE-GR-001", "WH-ATHENS");
        _storeAt("HONEY-GR-001", "WH-ATHENS");
        _storeAt("VACCINE-GR-001", "WH-ATHENS");

        // AGRI → IN_TRANSIT (perishable, en route from Kalamata)
        vm.startBroadcast(PRODUCER_KEY);
        tc.transferCustody("AGRI-GR-001", WAREHOUSE);
        vm.stopBroadcast();

        vm.startBroadcast(WAREHOUSE_KEY);
        tc.receiveBatch("AGRI-GR-001", "WH-KALAMATA");
        tc.transferCustody("AGRI-GR-001", TRANSPORTER);
        vm.stopBroadcast();

        vm.startBroadcast(TRANSPORTER_KEY);
        tc.shipBatch("AGRI-GR-001", "TRUCK-003");
        vm.stopBroadcast();

        // STEEL → STORED → DISTRIBUTED + certified (direct warehouse-to-distributor)
        _storeAt("STEEL-GR-001", "WH-PIR");

        vm.startBroadcast(WAREHOUSE_KEY);
        tc.transferCustody("STEEL-GR-001", DISTRIBUTOR);
        vm.stopBroadcast();

        vm.startBroadcast(DISTRIBUTOR_KEY);
        tc.distributeBatch("STEEL-GR-001", "DIST-PIR");
        vm.stopBroadcast();

        vm.startBroadcast(AUDITOR_KEY);
        tc.certifyBatch("STEEL-GR-001");
        vm.stopBroadcast();

        // ELEC, TEXT, CHEM remain PRODUCED — freshly created, not yet handed off
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    function _storeAt(bytes32 serial, bytes32 location) internal {
        vm.startBroadcast(PRODUCER_KEY);
        tc.transferCustody(serial, WAREHOUSE);
        vm.stopBroadcast();

        vm.startBroadcast(WAREHOUSE_KEY);
        tc.receiveBatch(serial, location);
        vm.stopBroadcast();
    }

    function _printSummary() internal view {
        console.log("=== TrustChain deployed at:", address(tc), "===");
        console.log("");
        console.log("Users registered: 5 (PRODUCER TRANSPORTER WAREHOUSE DISTRIBUTOR AUDITOR)");
        console.log("Batches created : 10");
        console.log("");
        console.log(
            "Route 1 - OLIVE-GR-001  : PRODUCED->STORED->IN_TRANSIT->STORED->IN_TRANSIT->DISTRIBUTED (certified)"
        );
        console.log("Route 2 - PHARMA-GR-001 : PRODUCED->STORED->IN_TRANSIT->DISTRIBUTED->RECALLED->STORED->DISPOSED");
        console.log("");
        console.log("Other batch states:");
        console.log("  WINE-GR-001    : STORED");
        console.log("  HONEY-GR-001   : STORED");
        console.log("  VACCINE-GR-001 : STORED");
        console.log("  AGRI-GR-001    : IN_TRANSIT");
        console.log("  STEEL-GR-001   : DISTRIBUTED (certified)");
        console.log("  ELEC-GR-001    : PRODUCED");
        console.log("  TEXT-GR-001    : PRODUCED");
        console.log("  CHEM-GR-001    : PRODUCED");
    }
}
