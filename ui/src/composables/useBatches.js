import { encodeBytes32String, decodeBytes32String } from 'ethers'
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

function decodeBatch(raw) {
  const statusIndex   = Number(raw.status)
  const categoryIndex = Number(raw.category)
  const expiry        = Number(raw.expiryDate)
  return {
    serialNumber:  fromBytes32(raw.serialNumber),
    quantity:      Number(raw.quantity),
    productTypeId: Number(raw.productTypeId),
    category:      categoryIndex,
    categoryLabel: CATEGORIES[categoryIndex],
    status:        statusIndex,
    statusLabel:   STATUSES[statusIndex],
    statusColor:   STATUS_COLORS[STATUSES[statusIndex]],
    origin:        fromBytes32(raw.origin),
    unitId:        Number(raw.unitId),
    producer:      raw.producer,
    currentHolder: raw.currentHolder,
    certified:     raw.certified,
    recalled:      raw.recalled,
    creationDate:  Number(raw.creationDate),
    expiryDate:    expiry > 0 ? expiry : null,
  }
}

// ── Composable ───────────────────────────────────────────────────────────────

export function useBatches() {
  const wallet = useWalletStore()

  // ── Reads ────────────────────────────────────────────────────────────────

  async function fetchBatch(serial) {
    const raw = await wallet.contract.getBatch(toBytes32(serial))
    return decodeBatch(raw)
  }

  // Batches created by the connected account
  async function fetchMyBatches() {
    const events = await wallet.contract.queryFilter(
      wallet.contract.filters.BatchCreated(null, wallet.account)
    )
    const serials = [...new Set(events.map(e => e.args.serialNumber))]
    return Promise.all(serials.map(async (s) => {
      const raw = await wallet.contract.getBatch(s)
      return decodeBatch(raw)
    }))
  }

  // All batches ever created (for auditor view)
  async function fetchAllBatches() {
    const events = await wallet.contract.queryFilter(
      wallet.contract.filters.BatchCreated()
    )
    const serials = [...new Set(events.map(e => e.args.serialNumber))]
    return Promise.all(serials.map(async (s) => {
      const raw = await wallet.contract.getBatch(s)
      return decodeBatch(raw)
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

  // Step 1 of every handoff — transfer custody to the next actor
  async function transferCustody(serial, newHolder) {
    try {
      const tx = await wallet.contract.transferCustody(toBytes32(serial), newHolder)
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
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

  return {
    fetchBatch,
    fetchMyBatches,
    fetchAllBatches,
    fetchHeldBatches,
    createBatch,
    transferCustody,
    receiveBatch,
    shipBatch,
    distributeBatch,
    recallBatch,
    disposeBatch,
    certifyBatch,
  }
}
