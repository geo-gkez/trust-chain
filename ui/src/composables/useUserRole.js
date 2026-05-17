import { ref, computed, watch } from 'vue'
import { decodeBytes32String } from 'ethers'
import { useWalletStore } from '@/stores/wallet'

export const ROLES = {
  0: 'PRODUCER',
  1: 'TRANSPORTER',
  2: 'WAREHOUSE',
  3: 'DISTRIBUTOR',
  4: 'AUDITOR',
  5: 'ADMIN',
}

export const ROLE_COLORS = {
  PRODUCER:    'green',
  TRANSPORTER: 'amber',
  WAREHOUSE:   'orange',
  DISTRIBUTOR: 'cyan',
  AUDITOR:     'purple',
  ADMIN:       'red',
}

// Module-level state — shared across all components that call useUserRole()
const roleIndex = ref(null)
const userName  = ref(null)
const isLoading = ref(false)

export function useUserRole() {
  const wallet = useWalletStore()

  const roleLabel = computed(() =>
    roleIndex.value !== null ? ROLES[roleIndex.value] : null
  )

  const roleColor = computed(() =>
    roleLabel.value ? ROLE_COLORS[roleLabel.value] : 'grey'
  )

  async function fetchRole() {
    if (!wallet.isConnected) { roleIndex.value = null; return }
    isLoading.value = true
    try {
      const user = await wallet.contract.getUser(wallet.account)
      if (!user.isActive) { roleIndex.value = null; return }
      roleIndex.value = Number(user.role)
      userName.value  = decodeBytes32String(user.name)
    } catch {
      roleIndex.value = null
    } finally {
      isLoading.value = false
    }
  }

  // Re-fetch on connect/disconnect and on account switch
  watch(() => wallet.isConnected, fetchRole, { immediate: true })
  watch(() => wallet.account, () => { if (wallet.isConnected) fetchRole() })

  return { roleLabel, roleColor, userName, isLoading }
}
