// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Roles assigned to users by the admin.
enum Role {
    PRODUCER,
    TRANSPORTER,
    WAREHOUSE,
    DISTRIBUTOR,
    AUDITOR,
    ADMIN
}

/// @notice Handling category of a product batch.
enum Category {
    PERISHABLE,
    REFRIGERATED,
    HAZARDOUS,
    NON_PERISHABLE,
    FRAGILE,
    OTHER
}

/// @notice Lifecycle state of a batch.
enum Status {
    PRODUCED,
    STORED,
    IN_TRANSIT,
    DISTRIBUTED,
    RECALLED,
    DISPOSED
}

/// @notice Registered user in the system.
struct User {
    // Slot 0 — 28 bytes used
    address ethAddress;
    Role role;
    bool isActive;
    uint48 registeredAt;
    // Slot 1 — 32 bytes
    bytes32 name;
}

/// @notice Product batch tracked through the supply chain.
/// @dev Keyed by `serialNumber` in the `batches` mapping — no internal uint256 id.
struct Batch {
    // Slot 0 — 32 bytes
    uint128 quantity;
    uint48 creationDate;
    uint48 expiryDate;
    uint8 productTypeId;
    Category category;
    Status status;
    bool recalled;
    // Slot 1 — 22 bytes used
    address producer;
    uint8 unitId;
    bool certified;
    // Slot 2 — 20 bytes used
    address currentHolder;
    // Slot 3 — 32 bytes
    bytes32 origin;
    // Slot 4 — 32 bytes (canonical key, kept in the struct for returns)
    bytes32 serialNumber;
}
