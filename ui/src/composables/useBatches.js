import { encodeBytes32String, decodeBytes32String, ZeroAddress } from 'ethers'
import { useWalletStore } from '@/stores/wallet'
import { parseContractError } from '@/utils/contractErrors'
import { gql } from '@/utils/graphql'

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
    const [data, { productTypes, units }] = await Promise.all([
      gql(`
        query($producer: Bytes!) {
          batchCreateds(first: 1000, where: { producer: $producer }) {
            serialNumber
          }
        }
      `, { producer: wallet.account.toLowerCase() }),
      fetchRegistries(),
    ])
    const serials = [...new Set(data.batchCreateds.map(e => e.serialNumber))]
    return Promise.all(serials.map(async (s) => {
      const raw = await wallet.contract.getBatch(s)
      return decodeBatch(raw, productTypes, units)
    }))
  }

  // All batches ever created (for auditor view)
  async function fetchAllBatches() {
    const [data, { productTypes, units }] = await Promise.all([
      gql(`{
        batchCreateds(first: 1000) {
          serialNumber
        }
      }`),
      fetchRegistries(),
    ])
    const serials = [...new Set(data.batchCreateds.map(e => e.serialNumber))]
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
  // The subgraph is used only to discover which serials were offered to us; every
  // field value is read live from chain. While an offer is pending, custody hasn't
  // moved, so the batch's currentHolder IS the proposer — authoritative and free of
  // the subgraph's "pick the latest CustodyProposed" guesswork.
  async function fetchPendingCustody() {
    const data = await gql(`
      query($to: Bytes!) {
        custodyProposeds(first: 1000, where: { to: $to }) {
          serialNumber
        }
      }
    `, { to: wallet.account.toLowerCase() })
    const serials = [...new Set(data.custodyProposeds.map(e => e.serialNumber))]
    const offers = await Promise.all(serials.map(async (s) => {
      const [pending, b] = await Promise.all([
        wallet.contract.pendingHolder(s),
        wallet.contract.getBatch(s),
      ])
      if (pending.toLowerCase() !== wallet.account.toLowerCase()) return null
      return { serial: fromBytes32(s), from: b.currentHolder }
    }))
    return offers.filter(Boolean)
  }

  // Live custody offers the connected account has MADE and can still cancel.
  // An offer is cancellable only while it is still pending AND the account is still the holder.
  async function fetchOutgoingCustody() {
    const data = await gql(`
      query($from: Bytes!) {
        custodyProposeds(first: 1000, where: { from: $from }) {
          serialNumber
        }
      }
    `, { from: wallet.account.toLowerCase() })
    const serials = [...new Set(data.custodyProposeds.map(e => e.serialNumber))]
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

    const data = await gql(`
      query($serial: Bytes!) {
        batchCreateds(where: { serialNumber: $serial }, orderBy: block_number, orderDirection: asc) {
          block_number
          transactionHash_
          producer
        }
        batchTransitioneds(where: { serialNumber: $serial }, orderBy: block_number, orderDirection: asc) {
          block_number
          transactionHash_
          from
          to
          by
          location
        }
        custodyProposeds(where: { serialNumber: $serial }, orderBy: block_number, orderDirection: asc) {
          block_number
          transactionHash_
          from
          to
        }
        custodyCancelleds(where: { serialNumber: $serial }, orderBy: block_number, orderDirection: asc) {
          block_number
          transactionHash_
          from
          to
        }
        custodyDeclineds(where: { serialNumber: $serial }, orderBy: block_number, orderDirection: asc) {
          block_number
          transactionHash_
          from
          to
        }
        custodyTransferreds(where: { serialNumber: $serial }, orderBy: block_number, orderDirection: asc) {
          block_number
          transactionHash_
          from
          to
        }
        batchCertifieds(where: { serialNumber: $serial }, orderBy: block_number, orderDirection: asc) {
          block_number
          transactionHash_
          auditor
        }
      }
    `, { serial: s })

    const entries = [
      ...data.batchCreateds.map(e => ({
        type:     'created',
        block:    Number(e.block_number),
        tx:       e.transactionHash_,
        producer: e.producer,
      })),
      ...data.batchTransitioneds.map(e => ({
        type:     'transitioned',
        block:    Number(e.block_number),
        tx:       e.transactionHash_,
        from:     STATUSES[Number(e.from)],
        to:       STATUSES[Number(e.to)],
        location: fromBytes32(e.location),
        actor:    e.by,
      })),
      ...data.custodyProposeds.map(e => ({
        type:  'proposed',
        block: Number(e.block_number),
        tx:    e.transactionHash_,
        from:  e.from,
        to:    e.to,
      })),
      ...data.custodyCancelleds.map(e => ({
        type:  'cancelled',
        block: Number(e.block_number),
        tx:    e.transactionHash_,
        from:  e.from,
        to:    e.to,
      })),
      ...data.custodyDeclineds.map(e => ({
        type:  'declined',
        block: Number(e.block_number),
        tx:    e.transactionHash_,
        from:  e.from,
        to:    e.to,
      })),
      ...data.custodyTransferreds.map(e => ({
        type:  'transferred',
        block: Number(e.block_number),
        tx:    e.transactionHash_,
        from:  e.from,
        to:    e.to,
      })),
      ...data.batchCertifieds.map(e => ({
        type:    'certified',
        block:   Number(e.block_number),
        tx:      e.transactionHash_,
        auditor: e.auditor,
      })),
    ]

    // Chronological: by block, then by tx hash as a stable tiebreaker
    return entries.sort((a, b) => a.block - b.block || a.tx.localeCompare(b.tx))
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
