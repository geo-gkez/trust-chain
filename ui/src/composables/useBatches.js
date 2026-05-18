import { encodeBytes32String, decodeBytes32String } from 'ethers'
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
    const data = await gql(`
      query($producer: String!) {
        batchCreateds(first: 1000, where: { producer: $producer }) {
          serialNumber
        }
      }
    `, { producer: wallet.account.toLowerCase() })
    const serials = [...new Set(data.batchCreateds.map(e => e.serialNumber))]
    return Promise.all(serials.map(async (s) => {
      const raw = await wallet.contract.getBatch(s)
      return decodeBatch(raw)
    }))
  }

  // All batches ever created (for auditor view)
  async function fetchAllBatches() {
    const data = await gql(`{
      batchCreateds(first: 1000) {
        serialNumber
      }
    }`)
    const serials = [...new Set(data.batchCreateds.map(e => e.serialNumber))]
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

  async function fetchBatchTimeline(serial) {
    const s = toBytes32(serial)

    const data = await gql(`
      query($serial: Bytes!) {
        batchCreateds(where: { serialNumber: $serial }, orderBy: blockNumber, orderDirection: asc) {
          blockNumber
          transactionHash
          producer
        }
        batchTransitioneds(where: { serialNumber: $serial }, orderBy: blockNumber, orderDirection: asc) {
          blockNumber
          transactionHash
          from
          to
          by
          location
        }
        custodyTransferreds(where: { serialNumber: $serial }, orderBy: blockNumber, orderDirection: asc) {
          blockNumber
          transactionHash
          from
          to
        }
        batchCertifieds(where: { serialNumber: $serial }, orderBy: blockNumber, orderDirection: asc) {
          blockNumber
          transactionHash
          auditor
        }
      }
    `, { serial: s })

    const key = e => Number(e.blockNumber) * 1e6 + parseInt(e.transactionHash.slice(-6), 16)

    const entries = [
      ...data.batchCreateds.map(e => ({
        type:     'created',
        _key:     key(e),
        block:    Number(e.blockNumber),
        producer: e.producer,
      })),
      ...data.batchTransitioneds.map(e => ({
        type:     'transitioned',
        _key:     key(e),
        block:    Number(e.blockNumber),
        from:     STATUSES[Number(e.from)],
        to:       STATUSES[Number(e.to)],
        location: fromBytes32(e.location),
        actor:    e.by,
      })),
      ...data.custodyTransferreds.map(e => ({
        type:  'transferred',
        _key:  key(e),
        block: Number(e.blockNumber),
        from:  e.from,
        to:    e.to,
      })),
      ...data.batchCertifieds.map(e => ({
        type:    'certified',
        _key:    key(e),
        block:   Number(e.blockNumber),
        auditor: e.auditor,
      })),
    ]

    return entries.sort((a, b) => a._key - b._key)
  }

  return {
    fetchBatch,
    fetchMyBatches,
    fetchAllBatches,
    fetchHeldBatches,
    fetchBatchTimeline,
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
