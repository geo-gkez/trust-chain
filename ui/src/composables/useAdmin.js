import { encodeBytes32String, decodeBytes32String } from 'ethers'
import { useWalletStore } from '@/stores/wallet'
import { parseContractError } from '@/utils/contractErrors'

function decodeUser(address, raw) {
  return {
    address,
    name:         decodeBytes32String(raw.name),
    role:         Number(raw.role),
    isActive:     raw.isActive,
    registeredAt: Number(raw.registeredAt),
  }
}

export function useAdmin() {
  const wallet = useWalletStore()

  // ── Reads ──────────────────────────────────────────────────────────────

  async function getProductTypes() {
    return wallet.contract.getProductTypes()
  }

  async function getUnits() {
    return wallet.contract.getUnits()
  }

  // ── Events-as-discovery: fetch all registered users ────────────────────

  async function fetchAllUsers() {
    const events = await wallet.contract.queryFilter(
      wallet.contract.filters.UserRegistered()
    )
    const addresses = [...new Set(events.map(e => e.args.user))]
    const users = await Promise.all(
      addresses.map(async (addr) => {
        const raw = await wallet.contract.getUser(addr)
        return decodeUser(addr, raw)
      })
    )
    return users
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  async function registerUser(address, name, role) {
    try {
      const tx = await wallet.contract.registerUser(
        address,
        encodeBytes32String(name),
        role,
      )
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function deactivateUser(address) {
    try {
      const tx = await wallet.contract.deactivateUser(address)
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function activateUser(address) {
    try {
      const tx = await wallet.contract.activateUser(address)
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function addProductType(name) {
    try {
      const tx = await wallet.contract.addProductType(name)
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  async function addUnit(name) {
    try {
      const tx = await wallet.contract.addUnit(name)
      await tx.wait()
    } catch (err) {
      throw new Error(parseContractError(err))
    }
  }

  return {
    getProductTypes,
    getUnits,
    fetchAllUsers,
    registerUser,
    deactivateUser,
    activateUser,
    addProductType,
    addUnit,
  }
}
