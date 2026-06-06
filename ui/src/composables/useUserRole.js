import { ref, computed, watch, effectScope } from 'vue'
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
const loadError = ref(false)   // true only on a genuine RPC/contract failure

// The watchers below are registered exactly once for the whole app, regardless
// of how many components call useUserRole(). They live in a detached effect
// scope so they aren't torn down when the first calling component unmounts.
let initialized = false

function initWatchers() {
  if (initialized) return
  initialized = true

  const wallet = useWalletStore()

  async function fetchRole() {
    if (!wallet.isConnected) { roleIndex.value = null; loadError.value = false; return }
    isLoading.value = true
    loadError.value = false
    try {
      const user = await wallet.contract.getUser(wallet.account)
      if (!user.isActive) { roleIndex.value = null; return }
      roleIndex.value = Number(user.role)
      userName.value  = decodeBytes32String(user.name)
    } catch {
      // getUser reads a mapping and never reverts for an unknown address, so a
      // throw here means an RPC/network/contract-address problem — not that the
      // user is simply unregistered.
      roleIndex.value = null
      loadError.value = true
    } finally {
      isLoading.value = false
    }
  }

  const scope = effectScope(true)
  scope.run(() => {
    watch(() => wallet.isConnected, fetchRole, { immediate: true })
    watch(() => wallet.account, () => { if (wallet.isConnected) fetchRole() })
  })
}

export function useUserRole() {
  initWatchers()

  const roleLabel = computed(() =>
    roleIndex.value !== null ? ROLES[roleIndex.value] : null
  )

  const roleColor = computed(() =>
    roleLabel.value ? ROLE_COLORS[roleLabel.value] : 'grey'
  )

  return { roleLabel, roleColor, userName, isLoading, loadError }
}
