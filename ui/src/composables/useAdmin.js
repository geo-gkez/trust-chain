import { ref } from 'vue'
import { useWalletStore } from '@/stores/wallet'
import { useToastStore } from '@/stores/toast'
import { ethers } from 'ethers'
import { bytes32ToString, stringToBytes32, parseContractError } from '@/composables/useBatches'

export function useAdmin() {
  const wallet  = useWalletStore()
  const toast   = useToastStore()
  const loading = ref(false)
  const error   = ref(null)

  function getContract() {
    if (!wallet.contract) throw new Error('Wallet not connected')
    return wallet.contract
  }

  // ── Registries ────────────────────────────────────────────────────────

  async function getProductTypes() {
    try {
      return await getContract().getProductTypes()
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return []
    }
  }

  async function getUnits() {
    try {
      return await getContract().getUnits()
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return []
    }
  }

  async function addProductType(name) {
    return _adminWrite('addProductType', [name], `Product type "${name}" added`)
  }

  async function addUnit(name) {
    return _adminWrite('addUnit', [name], `Unit "${name}" added`)
  }

  // ── Users ─────────────────────────────────────────────────────────────

  async function registerUser(address, nameStr, roleNum) {
    return _adminWrite(
      'registerUser',
      [address, stringToBytes32(nameStr), roleNum],
      'User registered successfully'
    )
  }

  async function deactivateUser(address) {
    return _adminWrite('deactivateUser', [address], 'User deactivated')
  }

  async function activateUser(address) {
    return _adminWrite('activateUser', [address], 'User activated')
  }

  async function fetchAllUsers() {
    try {
      const contract  = getContract()
      const events    = await contract.queryFilter(contract.filters.UserRegistered())
      const addresses = [...new Set(events.map((e) => e.args.user))]
      const users     = await Promise.all(addresses.map((addr) => getUser(addr)))
      return users.filter(Boolean)
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return []
    }
  }

  async function getUser(address) {
    try {
      const raw = await getContract().getUser(address)
      if (raw.ethAddress === ethers.ZeroAddress) return null
      return {
        ethAddress:   raw.ethAddress,
        role:         Number(raw.role),
        isActive:     raw.isActive,
        registeredAt: new Date(Number(raw.registeredAt) * 1000),
        name:         bytes32ToString(raw.name),
      }
    } catch (err) {
      const msg = parseContractError(err)
      error.value = msg
      toast.show(msg, 'error')
      return null
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────

  async function _adminWrite(method, args, successMsg) {
    loading.value = true
    error.value   = null
    try {
      const tx = await getContract()[method](...args)
      await tx.wait()
      if (successMsg) toast.show(successMsg, 'success')
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

  return {
    loading,
    error,
    getProductTypes,
    getUnits,
    addProductType,
    addUnit,
    registerUser,
    deactivateUser,
    activateUser,
    getUser,
    fetchAllUsers,
  }
}
