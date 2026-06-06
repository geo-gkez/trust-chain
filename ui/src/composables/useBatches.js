import { encodeBytes32String, decodeBytes32String, ZeroAddress } from 'ethers'
import { useWalletStore } from '@/stores/wallet'
import { parseContractError } from '@/utils/contractErrors'

// ── Enum maps ────────────────────────────────────────────────────────────────

// Must stay in sync with Status enum in DataTypes.sol
export const STATUSES = {
  0: 'PRODUCED',
  1: 'STORED',
  2: 'IN_TRANSIT',
  3: 'DISTRIBUTED',
  4: 'RECALLED',
  5: 'DISPOSED',
}

export const STATUS_COLORS = {
  PRODUCED:    'grey',
  STORED:      'blue',
  IN_TRANSIT:  'amber',
  DISTRIBUTED: 'green',
  RECALLED:    'red',
  DISPOSED:    'purple',
}

// Must stay in sync with Category enum in DataTypes.sol
export const CATEGORIES = {
  0: 'PERISHABLE',
  1: 'REFRIGERATED',
  2: 'HAZARDOUS',
  3: 'NON_PERISHABLE',
  4: 'FRAGILE',
  5: 'OTHER',
}

// ── Encoding helpers ─────────────────────────────────────────────────────────

export function toBytes32(str) {
  return encodeBytes32String(str)
}

export function fromBytes32(b) {
  try { return decodeBytes32String(b) } catch { return b }
}

// ── Batch decoder ────────────────────────────────────────────────────────────

// productTypes / units are the dynamic registries (string[] indexed by id) so
// the numeric productTypeId / unitId can be resolved to human-readable labels.
function decodeBatch(raw, productTypes = [], units = []) {
  const statusIndex      = Number(raw.status)
  const categoryIndex    = Number(raw.category)
  const productTypeIndex = Number(raw.productTypeId)
  const unitIndex        = Number(raw.unitId)
  const expiry           = Number(raw.expiryDate)
  return {
    serialNumber:     fromBytes32(raw.serialNumber),
    quantity:         Number(raw.quantity),
    productTypeId:    productTypeIndex,
    productTypeLabel: productTypes[productTypeIndex] ?? null,
    category:         categoryIndex,
    categoryLabel:    CATEGORIES[categoryIndex],
    status:           statusIndex,
    statusLabel:      STATUSES[statusIndex],
    statusColor:      STATUS_COLORS[STATUSES[statusIndex]],
    origin:           fromBytes32(raw.origin),
    unitId:           unitIndex,
    unitLabel:        units[unitIndex] ?? null,
    producer:         raw.producer,
    currentHolder:    raw.currentHolder,
    certified:        raw.certified,
    recalled:         raw.recalled,
    creationDate:     Number(raw.creationDate),
    expiryDate:       expiry > 0 ? expiry : null,
  }
}

// ── Composable ───────────────────────────────────────────────────────────────

export function useBatches() {
  const wallet = useWalletStore()

  // ── Reads ────────────────────────────────────────────────────────────────

  // The product-type / unit registries, fetched once per list load (not per
  // batch) so decodeBatch can resolve ids to labels.
  async function fetchRegistries() {
    const [productTypes, units] = await Promise.all([
      wallet.contract.getProductTypes(),
      wallet.contract.getUnits(),
    ])
    return { productTypes, units }
  }

  async function fetchBatch(serial) {
    const [raw, { productTypes, units }] = await Promise.all([
      wallet.contract.getBatch(toBytes32(serial)),
      fetchRegistries(),
    ])
    return decodeBatch(raw, productTypes, units)
  }

  // Batches created by the connected account
  async function fetchMyBatches() {
    const [events, { productTypes, units }] = await Promise.all([
      wallet.contract.queryFilter(
        wallet.contract.filters.BatchCreated(null, wallet.account)
      ),
      fetchRegistries(),
    ])
    const serials = [...new Set(events.map(e => e.args.serialNumber))]
    return Promise.all(serials.map(async (s) => {
      const raw = await wallet.contract.getBatch(s)
      return decodeBatch(raw, productTypes, units)
    }))
  }

  // All batches ever created (for auditor view)
  async function fetchAllBatches() {
    const [events, { productTypes, units }] = await Promise.all([
      wallet.contract.queryFilter(
        wallet.contract.filters.BatchCreated()
      ),
      fetchRegistries(),
    ])
    const serials = [...new Set(events.map(e => e.args.serialNumber))]
    return Promise.all(serials.map(async (s) => {
      const raw = await wallet.contract.getBatch(s)
      return decodeBatch(raw, productTypes, units)
    }))
  }

  // Batches where currentHolder is the connected account (who can act now)
  async function fetchHeldBatches() {
    const all = await fetchAllBatches()
    return all.filter(
      b => b.currentHolder.toLowerCase() === wallet.account.toLowerCase()
    )
  }

  // ── Writes ───────────────────────────────────────────────────────────────

  async function createBatch(serial, productTypeId, category, unitId, quantity, origin, expiryDate) {
    try {
      const tx = await wallet.contract.createBatch(
        toBytes32(serial),
        productTypeId,
        category,
        unitId,
        quantity,
        toBytes32(origin),
        expiryDate ?? 0,
      )
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  // Step 1 of a two-phase handoff — the current holder offers custody to the next actor.
  // Custody does not move until the recipient calls acceptCustody.
  async function proposeCustody(serial, newHolder) {
    try {
      const tx = await wallet.contract.proposeCustody(toBytes32(serial), newHolder)
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  // Step 2 of a two-phase handoff — the proposed recipient accepts and custody moves.
  async function acceptCustody(serial) {
    try {
      const tx = await wallet.contract.acceptCustody(toBytes32(serial))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  // The current holder retracts a pending custody offer before it is accepted.
  async function cancelCustody(serial) {
    try {
      const tx = await wallet.contract.cancelCustody(toBytes32(serial))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  // The proposed recipient declines a pending custody offer (custody stays with the holder).
  async function declineCustody(serial) {
    try {
      const tx = await wallet.contract.declineCustody(toBytes32(serial))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  // Pending custody offers addressed to the connected account (awaiting its acceptance).
  // Confirms each offer is still live via the public pendingHolder mapping.
  async function fetchPendingCustody() {
    const events = await wallet.contract.queryFilter(
      wallet.contract.filters.CustodyProposed(null, null, wallet.account)
    )
    const serials = [...new Set(events.map(e => e.args.serialNumber))]
    const offers = await Promise.all(serials.map(async (s) => {
      const pending = await wallet.contract.pendingHolder(s)
      if (pending.toLowerCase() !== wallet.account.toLowerCase()) return null
      const proposer = events.filter(e => e.args.serialNumber === s).at(-1)?.args.from
      return { serial: fromBytes32(s), from: proposer }
    }))
    return offers.filter(Boolean)
  }

  // Live custody offers the connected account has MADE and can still cancel.
  // An offer is cancellable only while it is still pending AND the account is still the holder.
  async function fetchOutgoingCustody() {
    const events = await wallet.contract.queryFilter(
      wallet.contract.filters.CustodyProposed(null, wallet.account, null)
    )
    const serials = [...new Set(events.map(e => e.args.serialNumber))]
    const offers = await Promise.all(serials.map(async (s) => {
      const pending = await wallet.contract.pendingHolder(s)
      if (pending === ZeroAddress) return null // accepted, cancelled, or cleared by a transition
      const b = await wallet.contract.getBatch(s)
      if (b.currentHolder.toLowerCase() !== wallet.account.toLowerCase()) return null // no longer your offer
      return { serial: fromBytes32(s), to: pending }
    }))
    return offers.filter(Boolean)
  }

  async function receiveBatch(serial, location) {
    try {
      const tx = await wallet.contract.receiveBatch(toBytes32(serial), toBytes32(location))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function shipBatch(serial, location) {
    try {
      const tx = await wallet.contract.shipBatch(toBytes32(serial), toBytes32(location))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function distributeBatch(serial, location) {
    try {
      const tx = await wallet.contract.distributeBatch(toBytes32(serial), toBytes32(location))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function recallBatch(serial, location) {
    try {
      const tx = await wallet.contract.recallBatch(toBytes32(serial), toBytes32(location))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function disposeBatch(serial, location) {
    try {
      const tx = await wallet.contract.disposeBatch(toBytes32(serial), toBytes32(location))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function certifyBatch(serial) {
    try {
      const tx = await wallet.contract.certifyBatch(toBytes32(serial))
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function fetchBatchTimeline(serial) {
    const s = toBytes32(serial)

    const [created, transitioned, proposed, cancelled, declined, transferred, certified] = await Promise.all([
      wallet.contract.queryFilter(wallet.contract.filters.BatchCreated(s)),
      wallet.contract.queryFilter(wallet.contract.filters.BatchTransitioned(s)),
      wallet.contract.queryFilter(wallet.contract.filters.CustodyProposed(s)),
      wallet.contract.queryFilter(wallet.contract.filters.CustodyCancelled(s)),
      wallet.contract.queryFilter(wallet.contract.filters.CustodyDeclined(s)),
      wallet.contract.queryFilter(wallet.contract.filters.CustodyTransferred(s)),
      wallet.contract.queryFilter(wallet.contract.filters.BatchCertified(s)),
    ])

    const entries = [
      ...created.map(e => ({
        type:     'created',
        block:    e.blockNumber,
        producer: e.args.producer,
      })),
      ...transitioned.map(e => ({
        type:     'transitioned',
        block:    e.blockNumber,
        from:     STATUSES[Number(e.args.from)],
        to:       STATUSES[Number(e.args.to)],
        location: fromBytes32(e.args.location),
        actor:    e.args.by,
      })),
      ...proposed.map(e => ({
        type:  'proposed',
        block: e.blockNumber,
        from:  e.args.from,
        to:    e.args.to,
      })),
      ...cancelled.map(e => ({
        type:  'cancelled',
        block: e.blockNumber,
        from:  e.args.from,
        to:    e.args.to,
      })),
      ...declined.map(e => ({
        type:  'declined',
        block: e.blockNumber,
        from:  e.args.from,
        to:    e.args.to,
      })),
      ...transferred.map(e => ({
        type:  'transferred',
        block: e.blockNumber,
        from:  e.args.from,
        to:    e.args.to,
      })),
      ...certified.map(e => ({
        type:    'certified',
        block:   e.blockNumber,
        auditor: e.args.auditor,
      })),
    ]

    return entries.sort((a, b) => a.block - b.block)
  }

  return {
    fetchBatch,
    fetchMyBatches,
    fetchAllBatches,
    fetchHeldBatches,
    fetchBatchTimeline,
    fetchPendingCustody,
    fetchOutgoingCustody,
    createBatch,
    proposeCustody,
    acceptCustody,
    cancelCustody,
    declineCustody,
    receiveBatch,
    shipBatch,
    distributeBatch,
    recallBatch,
    disposeBatch,
    certifyBatch,
  }
}
