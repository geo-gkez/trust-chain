// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Role, Category, Status, User, Batch} from "./DataTypes.sol";
import {ITrustChain} from "./ITrustChain.sol";

/// @title TrustChain — Supply Chain Traceability Contract
/// @notice Tracks product batches from production to distribution with role-based access control.
contract TrustChain is ITrustChain {
    // ── State Variables ─────────────────────────────────────────────────

    mapping(address => User) public users;

    mapping(bytes32 => Batch) public batches;

    uint8 public productTypeCount;
    mapping(uint8 => string) public productTypeNames;

    uint8 public unitCount;
    mapping(uint8 => string) public unitNames;

    mapping(Status => mapping(Status => bool)) public allowedTransitions;

    // ── Modifiers ───────────────────────────────────────────────────────

    modifier onlyAdmin() {
        _requireRole(msg.sender, Role.ADMIN);
        _;
    }

    modifier onlyProducer() {
        _requireRole(msg.sender, Role.PRODUCER);
        _;
    }

    modifier onlyTransporter() {
        _requireRole(msg.sender, Role.TRANSPORTER);
        _;
    }

    modifier onlyWarehouse() {
        _requireRole(msg.sender, Role.WAREHOUSE);
        _;
    }

    modifier onlyDistributor() {
        _requireRole(msg.sender, Role.DISTRIBUTOR);
        _;
    }

    modifier onlyAuditor() {
        _requireRole(msg.sender, Role.AUDITOR);
        _;
    }

    // ── Constructor ─────────────────────────────────────────────────────

    constructor() {
        _registerUser(msg.sender, "Admin", Role.ADMIN);

        _addProductType("FOOD");
        _addProductType("PHARMA");
        _addProductType("INDUSTRIAL");
        _addProductType("ELECTRONICS");
        _addProductType("AGRICULTURE");
        _addProductType("CHEMICAL");
        _addProductType("TEXTILE");

        _addUnit("KG");
        _addUnit("G");
        _addUnit("TON");
        _addUnit("L");
        _addUnit("ML");
        _addUnit("PCS");
        _addUnit("M2");

        allowedTransitions[Status.PRODUCED][Status.STORED] = true;
        allowedTransitions[Status.PRODUCED][Status.IN_TRANSIT] = true;
        allowedTransitions[Status.STORED][Status.IN_TRANSIT] = true;
        allowedTransitions[Status.STORED][Status.DISTRIBUTED] = true;
        allowedTransitions[Status.STORED][Status.DISPOSED] = true;
        allowedTransitions[Status.IN_TRANSIT][Status.STORED] = true;
        allowedTransitions[Status.IN_TRANSIT][Status.DISTRIBUTED] = true;
        allowedTransitions[Status.DISTRIBUTED][Status.RECALLED] = true;
        allowedTransitions[Status.RECALLED][Status.STORED] = true;
    }

    // ── Admin Domain (stubs) ────────────────────────────────────────────

    function registerUser(address user, bytes32 name, Role role) external onlyAdmin {
        _registerUser(user, name, role);
    }

    function deactivateUser(address user) external onlyAdmin {
        _requireRegistered(user).isActive = false;
        emit UserDeactivated(user);
    }

    function activateUser(address user) external onlyAdmin {
        _requireRegistered(user).isActive = true;
        emit UserActivated(user);
    }

    function addProductType(string calldata name) external onlyAdmin {
        _addProductType(name);
    }

    function addUnit(string calldata name) external onlyAdmin {
        _addUnit(name);
    }

    // ── Batch Domain (stubs) ────────────────────────────────────────────

    function createBatch(
        bytes32 serialNumber,
        uint8 productTypeId,
        Category category,
        uint8 unitId,
        uint128 quantity,
        bytes32 origin,
        uint48 expiryDate
    ) external onlyProducer {}

    // ── Lifecycle Domain (stubs) ────────────────────────────────────────

    function receiveBatch(bytes32 serialNumber, bytes32 location) external onlyWarehouse {}

    function shipBatch(bytes32 serialNumber, bytes32 location) external onlyTransporter {}

    function distributeBatch(bytes32 serialNumber, bytes32 location) external onlyDistributor {}

    function recallBatch(bytes32 serialNumber, bytes32 location) external onlyAuditor {}

    function certifyBatch(bytes32 serialNumber) external onlyAuditor {}

    function disposeBatch(bytes32 serialNumber, bytes32 location) external onlyWarehouse {}

    // ── View Domain (stubs) ─────────────────────────────────────────────

    function getBatch(bytes32 serialNumber) external view returns (Batch memory) {
        return batches[serialNumber];
    }

    function getUser(address user) external view returns (User memory) {
        return users[user];
    }

    function getProductTypes() external view returns (string[] memory) {
        string[] memory types = new string[](productTypeCount);
        for (uint8 i = 0; i < productTypeCount; i++) {
            types[i] = productTypeNames[i];
        }
        return types;
    }

    function getUnits() external view returns (string[] memory) {
        string[] memory u = new string[](unitCount);
        for (uint8 i = 0; i < unitCount; i++) {
            u[i] = unitNames[i];
        }
        return u;
    }

    // ── Internal Helpers ────────────────────────────────────────────────

    function _requireRole(address account, Role role) internal view {
        User storage u = users[account];
        if (!u.isActive || u.role != role) revert Unauthorized();
    }

    function _requireRegistered(address account) internal view returns (User storage u) {
        u = users[account];
        if (u.ethAddress == address(0)) revert NotRegistered();
    }

    /// @dev Invariants enforced here apply to every caller (constructor + external registerUser).
    /// Access control lives on the external function.
    function _registerUser(address account, bytes32 name, Role role) internal {
        if (account == address(0)) revert ZeroAddress();
        if (users[account].ethAddress != address(0)) revert AlreadyRegistered();

        users[account] =
            User({ethAddress: account, role: role, isActive: true, registeredAt: uint48(block.timestamp), name: name});
        emit UserRegistered(account, name, role);
    }

    function _addProductType(string memory name) internal {
        productTypeNames[productTypeCount] = name;
        emit ProductTypeAdded(productTypeCount, name);
        productTypeCount++;
    }

    function _addUnit(string memory name) internal {
        unitNames[unitCount] = name;
        emit UnitAdded(unitCount, name);
        unitCount++;
    }
}
