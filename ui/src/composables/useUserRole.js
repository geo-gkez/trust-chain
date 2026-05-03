import { ref, watch } from 'vue'
import { useWalletStore } from '@/stores/wallet'
import { storeToRefs } from 'pinia'

// Keep in sync with DataTypes.sol Role enum
export const ROLES = {
  0: 'PRODUCER',
  1: 'TRANSPORTER',
  2: 'WAREHOUSE',
  3: 'DISTRIBUTOR',
  4: 'AUDITOR',
  5: 'ADMIN',
}

export const ROLE_COLORS = {
  PRODUCER: 'green',
  TRANSPORTER: 'blue',
  WAREHOUSE: 'orange',
  DISTRIBUTOR: 'cyan',
  AUDITOR: 'purple',
  ADMIN: 'red',
}

export function useUserRole() {
  const wallet = useWalletStore()
  const { account, contract } = storeToRefs(wallet)

  const role = ref(null)       // numeric Role value (0-5) or null
  const roleLabel = ref(null)  // e.g. 'ADMIN'
  const isActive = ref(false)
  const isRegistered = ref(false)
  const isLoading = ref(false)

  async function fetchRole() {
    if (!account.value || !contract.value) {
      role.value = null
      roleLabel.value = null
      isActive.value = false
      isRegistered.value = false
      return
    }
    isLoading.value = true
    try {
      const user = await contract.value.getUser(account.value)
      // user.ethAddress == zero address means not registered
      if (user.ethAddress === '0x0000000000000000000000000000000000000000') {
        role.value = null
        roleLabel.value = null
        isActive.value = false
        isRegistered.value = false
      } else {
        role.value = Number(user.role)
        roleLabel.value = ROLES[role.value] ?? 'UNKNOWN'
        isActive.value = user.isActive
        isRegistered.value = true
      }
    } catch {
      role.value = null
      roleLabel.value = null
      isActive.value = false
      isRegistered.value = false
    } finally {
      isLoading.value = false
    }
  }

  // Re-fetch whenever account or contract changes
  watch([account, contract], () => fetchRole(), { immediate: true })

  return { role, roleLabel, isActive, isRegistered, isLoading, fetchRole }
}
