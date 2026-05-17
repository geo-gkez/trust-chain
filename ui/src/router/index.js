import { createRouter, createWebHashHistory } from 'vue-router'
import { useWalletStore } from '@/stores/wallet'
import HomeView        from '@/views/HomeView.vue'
import DashboardView   from '@/views/DashboardView.vue'
import SearchView      from '@/views/SearchView.vue'
import BatchDetailView from '@/views/BatchDetailView.vue'

const routes = [
  { path: '/',                component: HomeView },
  { path: '/dashboard',       component: DashboardView,   meta: { requiresAuth: true } },
  { path: '/search',          component: SearchView,       meta: { requiresAuth: true } },
  { path: '/batch/:serial',   component: BatchDetailView,  meta: { requiresAuth: true } },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

router.beforeEach((to) => {
  if (to.meta.requiresAuth) {
    const wallet = useWalletStore()
    if (!wallet.isConnected) {
      return { path: '/', query: { reason: 'unregistered' } }
    }
  }
})

export default router
