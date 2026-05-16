// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Role, Category, Status, User, Batch} from "./DataTypes.sol";

/// @title ITrustChain — Supply Chain Traceability Interface
/// @notice Defines the public API and events for the TrustChain contract.
interface ITrustChain {
    // ── Events ──────────────────────────────────────────────────────────

    event UserRegistered(address indexed user, bytes32 name, Role role);
    event UserDeactivated(address indexed user);
    event UserActivated(address indexed user);
    event ProductTypeAdded(uint8 indexed id, string name);
    event UnitAdded(uint8 indexed id, string name);

    event BatchCreated(bytes32 indexed serialNumber, address indexed producer);

    event BatchTransitioned(
        bytes32 indexed serialNumber, Status indexed from, Status indexed to, bytes32 location, address by, uint48 at
    );

    event BatchCertified(bytes32 indexed serialNumber, address indexed auditor);
    event BatchRecalled(bytes32 indexed serialNumber, address indexed auditor);
    event CustodyTransferred(bytes32 indexed serialNumber, address indexed from, address indexed to);

    // ── Custom Errors ───────────────────────────────────────────────────

    error ZeroAddress();
    error AlreadyRegistered();
    error NotRegistered();
    error Unauthorized();
    error BatchNotFound();
    error DuplicateSerial();
    error InvalidSerialNumber();
    error InvalidProductType();
    error InvalidUnit();
    error InvalidQuantity();
    error InvalidOrigin();
    error InvalidExpiryDate();
    error InvalidTransition(Status from, Status to);
    error CannotDistributeRecalled();
    error BatchNotRecalled();
    error NotCurrentHolder();
    error BatchExpired();
    error SelfDeactivation();
    error CannotCertifyInStatus(Status status);
    error AlreadyCertified();
    error DuplicateProductType();
    error DuplicateUnit();

    // ── Admin Domain ────────────────────────────────────────────────────

    function registerUser(address user, bytes32 name, Role role) external;
    function deactivateUser(address user) external;
    function activateUser(address user) external;
    function addProductType(string calldata name) external;
    function addUnit(string calldata name) external;

    // ── Batch Domain ────────────────────────────────────────────────────

    function createBatch(
        bytes32 serialNumber,
        uint8 productTypeId,
        Category category,
        uint8 unitId,
        uint128 quantity,
        bytes32 origin,
        uint48 expiryDate
    ) external;

    // ── Lifecycle Domain ────────────────────────────────────────────────

    function transferCustody(bytes32 serialNumber, address newHolder) external;
    function receiveBatch(bytes32 serialNumber, bytes32 location) external;
    function shipBatch(bytes32 serialNumber, bytes32 location) external;
    function distributeBatch(bytes32 serialNumber, bytes32 location) external;
    function recallBatch(bytes32 serialNumber, bytes32 location) external;
    function certifyBatch(bytes32 serialNumber) external;
    function disposeBatch(bytes32 serialNumber, bytes32 location) external;

    // ── View Domain ─────────────────────────────────────────────────────

    function getBatch(bytes32 serialNumber) external view returns (Batch memory);
    function getUser(address user) external view returns (User memory);
    function getProductTypes() external view returns (string[] memory);
    function getUnits() external view returns (string[] memory);
}
