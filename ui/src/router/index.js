import { createRouter, createWebHistory } from 'vue-router'
import { useWalletStore } from '@/stores/wallet'

const routes = [
  {
    path: '/',
    name: 'home',
    component: () => import('@/views/HomeView.vue'),
  },
  {
    path: '/dashboard',
    name: 'dashboard',
    component: () => import('@/views/DashboardView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/batch/:serial',
    name: 'batch-detail',
    component: () => import('@/views/BatchDetailView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/search',
    name: 'search',
    component: () => import('@/views/SearchView.vue'),
    meta: { requiresAuth: true },
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  if (!to.meta.requiresAuth) return true

  const wallet = useWalletStore()
  if (!wallet.isConnected) {
    return { name: 'home', query: { redirect: to.fullPath } }
  }

  // Check that the account is actually registered on-chain
  try {
    const user = await wallet.contract.getUser(wallet.account)
    if (user.ethAddress === '0x0000000000000000000000000000000000000000') {
      return { name: 'home', query: { reason: 'unregistered' } }
    }
    if (!user.isActive) {
      return { name: 'home', query: { reason: 'inactive' } }
    }
  } catch {
    return { name: 'home', query: { reason: 'error' } }
  }

  return true
})

export default router
