import { ref } from 'vue'
import { useWalletStore } from '@/stores/wallet'
import { useToastStore } from '@/stores/toast'
import { ethers } from 'ethers'

export function parseContractError(err) {
  if (err.reason)       return err.reason
  if (err.shortMessage) return err.shortMessage
  const msg = err.message ?? ''
  if (msg.includes('Unauthorized'))              return 'Unauthorized — wrong role or inactive account.'
  if (msg.includes('BatchNotFound'))             return 'Batch not found.'
  if (msg.includes('DuplicateSerial'))           return 'A batch with this serial number already exists.'
  if (msg.includes('InvalidTransition'))         return 'This status transition is not allowed.'
  if (msg.includes('CannotDistributeRecalled'))  return 'Cannot distribute a recalled batch.'
  if (msg.includes('BatchNotRecalled'))          return 'Batch must be recalled before disposing.'
  if (msg.includes('execution reverted'))        return 'Transaction rejected by contract.'
  return msg
}

// Keep in sync with DataTypes.sol Status enum
export const STATUS_LABELS = {
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
  DISPOSED:    'deep-purple',
}

export const CATEGORY_LABELS = {
  0: 'PERISHABLE',
  1: 'REFRIGERATED',
  2: 'HAZARDOUS',
  3: 'NON_PERISHABLE',
  4: 'FRAGILE',
  5: 'OTHER',
}

/** Convert a bytes32 value from the contract to a human-readable string. */
export function bytes32ToString(b32) {
  try {
    return ethers.decodeBytes32String(b32)
  } catch {
    return b32
  }
}

/** Convert a human-readable string to bytes32 (padded). */
export function stringToBytes32(str) {
  return ethers.encodeBytes32String(str)
}

/**
 * Decode a raw Batch struct returned by the contract into a plain JS object
 * with human-readable fields.
 */
export function decodeBatch(raw) {
  const statusNum = Number(raw.status)
  const categoryNum = Number(raw.category)
  return {
    serialNumber:  bytes32ToString(raw.serialNumber),
    serialRaw:     raw.serialNumber,
    productTypeId: Number(raw.productTypeId),
    category:      CATEGORY_LABELS[categoryNum] ?? categoryNum,
    status:        STATUS_LABELS[statusNum] ?? statusNum,
    statusNum,
    quantity:      raw.quantity.toString(),
    unitId:        Number(raw.unitId),
    creationDate:  new Date(Number(raw.creationDate) * 1000),
    expiryDate:    raw.expiryDate > 0 ? new Date(Number(raw.expiryDate) * 1000) : null,
    producer:      raw.producer,
    currentHolder: raw.currentHolder,
    origin:        bytes32ToString(raw.origin),
    certified:     raw.certified,
    recalled:      raw.recalled,
  }
}

export function useBatches() {
  const wallet = useWalletStore()
  const toast  = useToastStore()
  const loading = ref(false)
  const error   = ref(null)

  function getContract() {
    if (!wallet.contract) throw new Error('Wallet not connected')
    return wallet.contract
  }

  // ── Read ──────────────────────────────────────────────────────────────

  async function fetchBatch(serialStr) {
    loading.value = true
    error.value   = null
    try {
      const serial = stringToBytes32(serialStr)
      const raw    = await getContract().getBatch(serial)
      if (raw.serialNumber === ethers.ZeroHash) return null
      return decodeBatch(raw)
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return null
    } finally {
      loading.value = false
    }
  }

  /**
   * Returns the full event timeline for a batch.
   * Each entry: { type, from, to, location, by, at, txHash }
   */
  async function fetchBatchTimeline(serialStr) {
    loading.value = true
    error.value   = null
    try {
      const contract = getContract()
      const serial   = stringToBytes32(serialStr)

      // BatchCreated
      const createdFilter = contract.filters.BatchCreated(serial)
      const createdEvents = await contract.queryFilter(createdFilter)

      // BatchTransitioned
      const transFilter  = contract.filters.BatchTransitioned(serial)
      const transEvents  = await contract.queryFilter(transFilter)

      const created = createdEvents.map((e) => ({
        type:     'created',
        producer: e.args.producer,
        at:       null, // fetched below
        block:    e.blockNumber,
        txHash:   e.transactionHash,
      }))

      const transitions = transEvents.map((e) => ({
        type:     'transition',
        from:     STATUS_LABELS[Number(e.args.from)] ?? Number(e.args.from),
        to:       STATUS_LABELS[Number(e.args.to)]   ?? Number(e.args.to),
        location: bytes32ToString(e.args.location),
        by:       e.args.by,
        at:       new Date(Number(e.args.at) * 1000),
        block:    e.blockNumber,
        txHash:   e.transactionHash,
      }))

      // Fetch block timestamp for the creation event
      if (created.length > 0) {
        try {
          const block = await wallet.provider.getBlock(created[0].block)
          created[0].at = new Date(block.timestamp * 1000)
        } catch { /* non-fatal */ }
      }

      return [...created, ...transitions].sort((a, b) => a.block - b.block)
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return []
    } finally {
      loading.value = false
    }
  }

  /**
   * Fetch batches created by the current account (PRODUCER).
   * Returns decoded batch objects.
   */
  async function fetchMyBatches() {
    loading.value = true
    error.value   = null
    try {
      const contract = getContract()
      const filter   = contract.filters.BatchCreated(null, wallet.account)
      const events   = await contract.queryFilter(filter)
      const serials  = events.map((e) => e.args.serialNumber)
      const batches  = await Promise.all(
        serials.map((s) => contract.getBatch(s).then(decodeBatch))
      )
      return batches
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return []
    } finally {
      loading.value = false
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────

  async function createBatch({ serialNumber, productTypeId, category, unitId, quantity, origin, expiryDate }) {
    loading.value = true
    error.value   = null
    try {
      const tx = await getContract().createBatch(
        stringToBytes32(serialNumber),
        productTypeId,
        category,
        unitId,
        quantity,
        stringToBytes32(origin),
        expiryDate ?? 0
      )
      await tx.wait()
      toast.show('Batch created successfully', 'success')
      return true
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return false
    } finally {
      loading.value = false
    }
  }

  async function receiveBatch(serialStr, locationStr) {
    return _transition('receiveBatch', serialStr, locationStr)
  }

  async function shipBatch(serialStr, locationStr) {
    return _transition('shipBatch', serialStr, locationStr)
  }

  async function distributeBatch(serialStr, locationStr) {
    return _transition('distributeBatch', serialStr, locationStr)
  }

  async function recallBatch(serialStr, locationStr) {
    return _transition('recallBatch', serialStr, locationStr)
  }

  async function disposeBatch(serialStr, locationStr) {
    return _transition('disposeBatch', serialStr, locationStr)
  }

  async function certifyBatch(serialStr) {
    loading.value = true
    error.value   = null
    try {
      const tx = await getContract().certifyBatch(stringToBytes32(serialStr))
      await tx.wait()
      toast.show('Batch certified successfully', 'success')
      return true
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return false
    } finally {
      loading.value = false
    }
  }

  const TRANSITION_MESSAGES = {
    receiveBatch:    'Batch received — status: STORED',
    shipBatch:       'Batch shipped — status: IN TRANSIT',
    distributeBatch: 'Batch distributed successfully',
    recallBatch:     'Batch recalled',
    disposeBatch:    'Batch disposed',
  }

  async function _transition(method, serialStr, locationStr) {
    loading.value = true
    error.value   = null
    try {
      const tx = await getContract()[method](
        stringToBytes32(serialStr),
        stringToBytes32(locationStr)
      )
      await tx.wait()
      toast.show(TRANSITION_MESSAGES[method] ?? 'Transaction confirmed', 'success')
      return true
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return false
    } finally {
      loading.value = false
    }
  }

  /**
   * Returns every batch in the contract by replaying BatchCreated events.
   * Each entry is a fully decoded Batch object (same shape as fetchBatch).
   */
  async function fetchAllBatches() {
    loading.value = true
    error.value   = null
    try {
      const contract = getContract()
      const events   = await contract.queryFilter(contract.filters.BatchCreated())
      const serials  = [...new Set(events.map((e) => e.args.serialNumber))]
      const raws     = await Promise.all(serials.map((s) => contract.getBatch(s)))
      return raws
        .filter((r) => r.serialNumber !== ethers.ZeroHash)
        .map(decodeBatch)
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return []
    } finally {
      loading.value = false
    }
  }

  /**
   * Returns batches currently held by the connected account.
   * Replays all BatchCreated events, fetches each batch, and filters by currentHolder.
   */
  async function fetchHeldBatches() {
    loading.value = true
    error.value   = null
    try {
      const contract = getContract()
      const events   = await contract.queryFilter(contract.filters.BatchCreated())
      const serials  = [...new Set(events.map((e) => e.args.serialNumber))]
      const raws     = await Promise.all(serials.map((s) => contract.getBatch(s)))
      return raws
        .filter((r) =>
          r.serialNumber !== ethers.ZeroHash &&
          r.currentHolder.toLowerCase() === wallet.account.toLowerCase()
        )
        .map(decodeBatch)
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return []
    } finally {
      loading.value = false
    }
  }

  return {
    loading,
    error,
    fetchBatch,
    fetchBatchTimeline,
    fetchMyBatches,
    fetchAllBatches,
    fetchHeldBatches,
    createBatch,
    receiveBatch,
    shipBatch,
    distributeBatch,
    recallBatch,
    certifyBatch,
    disposeBatch,
  }
}
