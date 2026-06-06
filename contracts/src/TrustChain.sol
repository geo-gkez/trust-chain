// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Role, Category, Status, User, Batch} from "./DataTypes.sol";
import {ITrustChain} from "./ITrustChain.sol";

/// @title TrustChain — Supply Chain Traceability Contract
/// @notice Tracks product batches from production to distribution with role-based access control.
contract TrustChain is ITrustChain {
    // ── State Variables ─────────────────────────────────────────────────

    mapping(address => User) public users;

    /// @notice All batches, keyed by serial number. A zero serialNumber field
    /// means the slot is empty (used as the existence check).
    mapping(bytes32 => Batch) public batches;

    // Product-type registry: 0-indexed (ids 0..productTypeCount-1); the count is
    // the exclusive upper bound for enumeration (Solidity mappings aren't iterable).
    uint8 public productTypeCount;
    mapping(uint8 => string) public productTypeNames;

    // Measurement-unit registry: same 0-indexed pattern, bounded by unitCount.
    uint8 public unitCount;
    mapping(uint8 => string) public unitNames;

    /// @dev State-machine adjacency matrix: allowedTransitions[from][to] == true
    /// permits that Status change. Populated in the constructor.
    mapping(Status => mapping(Status => bool)) private allowedTransitions;

    /// @notice Pending custody offer per batch. Set by `proposeCustody`, consumed by
    /// `acceptCustody`, cleared by `cancelCustody` or any status transition. address(0) = none.
    mapping(bytes32 => address) public pendingHolder;

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
        allowedTransitions[Status.PRODUCED][Status.RECALLED] = true;
        allowedTransitions[Status.STORED][Status.IN_TRANSIT] = true;
        allowedTransitions[Status.STORED][Status.DISTRIBUTED] = true;
        allowedTransitions[Status.STORED][Status.DISPOSED] = true;
        allowedTransitions[Status.STORED][Status.RECALLED] = true;
        allowedTransitions[Status.IN_TRANSIT][Status.STORED] = true;
        allowedTransitions[Status.IN_TRANSIT][Status.DISTRIBUTED] = true;
        allowedTransitions[Status.IN_TRANSIT][Status.RECALLED] = true;
        allowedTransitions[Status.DISTRIBUTED][Status.RECALLED] = true;
        allowedTransitions[Status.RECALLED][Status.STORED] = true;
    }

    // ── Admin Domain ──────────────────────────────────────────────────────

    function registerUser(address user, bytes32 name, Role role) external onlyAdmin {
        _registerUser(user, name, role);
    }

    function deactivateUser(address user) external onlyAdmin {
        if (user == msg.sender) revert SelfDeactivation();
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

    // ── Batch Domain ──────────────────────────────────────────────────────

    function createBatch(
        bytes32 serialNumber,
        uint8 productTypeId,
        Category category,
        uint8 unitId,
        uint128 quantity,
        bytes32 origin,
        uint48 expiryDate
    ) external onlyProducer {
        if (productTypeId >= productTypeCount) revert InvalidProductType();
        if (unitId >= unitCount) revert InvalidUnit();
        if (serialNumber == bytes32(0)) revert InvalidSerialNumber();
        if (quantity == 0) revert InvalidQuantity();
        if (origin == bytes32(0)) revert InvalidOrigin();
        if (expiryDate != 0 && expiryDate < block.timestamp) revert InvalidExpiryDate();
        if (batches[serialNumber].serialNumber != bytes32(0)) {
            revert DuplicateSerial();
        }

        batches[serialNumber] = Batch({
            quantity: quantity,
            creationDate: uint48(block.timestamp),
            expiryDate: expiryDate,
            productTypeId: productTypeId,
            category: category,
            status: Status.PRODUCED,
            recalled: false,
            producer: msg.sender,
            unitId: unitId,
            certified: false,
            currentHolder: msg.sender,
            origin: origin,
            serialNumber: serialNumber
        });

        emit BatchCreated(serialNumber, msg.sender);
    }

    // ── Lifecycle Domain ────────────────────────────────────────────────

    /// @notice Step 1 of a two-phase handoff: the current holder offers custody to `newHolder`.
    /// @dev Custody does NOT move here — the recipient must call `acceptCustody`. This models a
    /// real physical handoff where the receiver explicitly accepts delivery, and prevents dumping
    /// a batch onto an unwilling or wrong-role party. The caller must be an active user, so a
    /// deactivated holder can no longer offload a batch they hold.
    function proposeCustody(bytes32 serialNumber, address newHolder) external {
        Batch storage b = _requireBatch(serialNumber);
        if (b.currentHolder != msg.sender) revert NotCurrentHolder();
        if (!users[msg.sender].isActive) revert Unauthorized();
        if (newHolder == msg.sender) revert SelfTransfer();
        if (newHolder == address(0)) revert ZeroAddress();
        if (!users[newHolder].isActive) revert Unauthorized();

        pendingHolder[serialNumber] = newHolder;

        emit CustodyProposed(serialNumber, msg.sender, newHolder);
    }

    /// @notice Step 2 of a two-phase handoff: the proposed recipient accepts and custody moves.
    function acceptCustody(bytes32 serialNumber) external {
        Batch storage b = _requireBatch(serialNumber);
        address to = pendingHolder[serialNumber];
        if (to == address(0)) revert NoPendingCustody();
        if (to != msg.sender) revert NotPendingHolder();
        if (!users[msg.sender].isActive) revert Unauthorized();

        address oldHolder = b.currentHolder;
        b.currentHolder = msg.sender;
        delete pendingHolder[serialNumber];

        emit CustodyTransferred(serialNumber, oldHolder, msg.sender);
    }

    /// @notice The current holder retracts a pending custody offer before it is accepted.
    function cancelCustody(bytes32 serialNumber) external {
        Batch storage b = _requireBatch(serialNumber);
        if (b.currentHolder != msg.sender) revert NotCurrentHolder();
        address to = pendingHolder[serialNumber];
        if (to == address(0)) revert NoPendingCustody();

        delete pendingHolder[serialNumber];

        emit CustodyCancelled(serialNumber, msg.sender, to);
    }

    /// @notice The proposed recipient declines a pending custody offer. Custody stays with the holder.
    function declineCustody(bytes32 serialNumber) external {
        Batch storage b = _requireBatch(serialNumber);
        address to = pendingHolder[serialNumber];
        if (to == address(0)) revert NoPendingCustody();
        if (to != msg.sender) revert NotPendingHolder();

        delete pendingHolder[serialNumber];

        emit CustodyDeclined(serialNumber, b.currentHolder, msg.sender);
    }

    function receiveBatch(bytes32 serialNumber, bytes32 location) external onlyWarehouse {
        Batch storage b = _requireBatch(serialNumber);
        if (b.currentHolder != msg.sender) revert NotCurrentHolder();
        _transition(b, serialNumber, Status.STORED, location);
    }

    function shipBatch(bytes32 serialNumber, bytes32 location) external onlyTransporter {
        Batch storage b = _requireBatch(serialNumber);
        if (b.currentHolder != msg.sender) revert NotCurrentHolder();
        _transition(b, serialNumber, Status.IN_TRANSIT, location);
    }

    function distributeBatch(bytes32 serialNumber, bytes32 location) external onlyDistributor {
        Batch storage b = _requireBatch(serialNumber);
        if (b.recalled) revert CannotDistributeRecalled();
        if (b.currentHolder != msg.sender) revert NotCurrentHolder();
        _transition(b, serialNumber, Status.DISTRIBUTED, location);
    }

    /// @notice Recalls a batch. After this call the auditor becomes `currentHolder`.
    /// @dev A recall is a unilateral regulatory seizure: unlike a normal handoff it does NOT use
    /// the propose/accept flow, because requiring the current holder's consent would let a bad
    /// actor block the seizure. To later dispose the batch, the auditor proposes custody to a
    /// warehouse (`proposeCustody`), the warehouse accepts (`acceptCustody`) and receives it.
    function recallBatch(bytes32 serialNumber, bytes32 location) external onlyAuditor {
        Batch storage b = _requireBatch(serialNumber);
        b.recalled = true;
        _transition(b, serialNumber, Status.RECALLED, location);

        emit BatchRecalled(serialNumber, msg.sender);
    }

    function certifyBatch(bytes32 serialNumber) external onlyAuditor {
        Batch storage b = _requireBatch(serialNumber);
        if (b.status != Status.DISTRIBUTED) revert CannotCertifyInStatus(b.status);
        if (b.certified) revert AlreadyCertified();

        b.certified = true;

        emit BatchCertified(serialNumber, msg.sender);
    }

    /// @notice Disposes a recalled batch. The warehouse must be the `currentHolder`
    /// (the auditor proposes custody to the warehouse after `recallBatch`, the warehouse
    /// accepts via `acceptCustody`, then receives the batch into quarantine).
    function disposeBatch(bytes32 serialNumber, bytes32 location) external onlyWarehouse {
        Batch storage b = _requireBatch(serialNumber);
        if (!b.recalled) revert BatchNotRecalled();
        if (b.currentHolder != msg.sender) revert NotCurrentHolder();

        _transition(b, serialNumber, Status.DISPOSED, location);
    }

    // ── View Domain ───────────────────────────────────────────────────────

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
        bytes32 nameHash = keccak256(bytes(name));
        for (uint8 i = 0; i < productTypeCount; i++) {
            if (keccak256(bytes(productTypeNames[i])) == nameHash) revert DuplicateProductType();
        }
        productTypeNames[productTypeCount] = name;

        emit ProductTypeAdded(productTypeCount, name);

        productTypeCount++;
    }

    function _addUnit(string memory name) internal {
        bytes32 nameHash = keccak256(bytes(name));
        for (uint8 i = 0; i < unitCount; i++) {
            if (keccak256(bytes(unitNames[i])) == nameHash) revert DuplicateUnit();
        }
        unitNames[unitCount] = name;
        emit UnitAdded(unitCount, name);
        unitCount++;
    }

    function _requireBatch(bytes32 serialNumber) internal view returns (Batch storage b) {
        b = batches[serialNumber];
        if (b.serialNumber == bytes32(0)) revert BatchNotFound();
    }

    /// @dev Core status-transition routine. Validates the move against
    /// `allowedTransitions` (enforcing expiry except on reverse-logistics paths),
    /// updates state, clears any pending custody offer, and emits BatchTransitioned.
    /// Callers pass the already-loaded storage ref from `_requireBatch`.
    function _transition(Batch storage b, bytes32 serialNumber, Status to, bytes32 location) internal {
        // Expiry blocks forward commerce only. Any transition that is part of reverse
        // logistics (currently in RECALLED, or heading to RECALLED / DISPOSED) must
        // always succeed so expired/contaminated goods can be removed from the chain.
        if (b.status != Status.RECALLED && to != Status.RECALLED && to != Status.DISPOSED) {
            if (b.expiryDate != 0 && b.expiryDate < block.timestamp) revert BatchExpired();
        }

        Status from = b.status;

        if (!allowedTransitions[from][to]) revert InvalidTransition(from, to);

        b.status = to;
        b.currentHolder = msg.sender;

        // A status change invalidates any stale custody offer made under the previous state.
        delete pendingHolder[serialNumber];

        emit BatchTransitioned(serialNumber, from, to, location, msg.sender, uint48(block.timestamp));
    }
}
