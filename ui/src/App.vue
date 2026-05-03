<template>
  <v-app theme="trustChainTheme">
    <!-- ── App Bar ───────────────────────────────────────────────────── -->
    <v-app-bar elevation="2" color="surface">
      <v-app-bar-nav-icon @click="drawer = !drawer" />

      <v-app-bar-title>
        <v-icon icon="mdi-link-variant" color="primary" class="mr-2" />
        <span class="font-weight-bold">TrustChain</span>
      </v-app-bar-title>

      <v-spacer />

      <!-- Desktop nav links (hidden on mobile) -->
      <template v-if="wallet.isConnected">
        <v-btn
          v-for="link in navLinks"
          :key="link.to"
          :to="link.to"
          variant="text"
          class="d-none d-md-inline-flex"
        >
          <v-icon :icon="link.icon" class="mr-1" />
          {{ link.label }}
        </v-btn>
      </template>

      <RoleBadge v-if="roleLabel" :role="roleLabel" class="mx-2 d-none d-sm-flex" />
      <WalletConnect class="ml-2 mr-2" />
    </v-app-bar>

    <!-- ── Navigation Drawer (mobile + sidebar) ────────────────────── -->
    <v-navigation-drawer v-model="drawer" temporary>
      <v-list-item
        prepend-icon="mdi-link-variant"
        title="TrustChain"
        subtitle="Supply Chain Traceability"
        nav
      />

      <v-divider />

      <v-list v-if="wallet.isConnected" density="compact" nav>
        <v-list-item
          v-for="link in navLinks"
          :key="link.to"
          :prepend-icon="link.icon"
          :title="link.label"
          :to="link.to"
          @click="drawer = false"
        />
      </v-list>

      <v-divider v-if="wallet.isConnected" />

      <v-list density="compact" nav>
        <v-list-item>
          <RoleBadge v-if="roleLabel" :role="roleLabel" />
          <span v-else class="text-medium-emphasis text-body-2">Not connected</span>
        </v-list-item>
        <v-list-item>
          <WalletConnect block />
        </v-list-item>
      </v-list>
    </v-navigation-drawer>

    <!-- ── Main Content ─────────────────────────────────────────────── -->
    <v-main>
      <!-- Wallet error banner -->
      <v-alert
        v-if="wallet.error"
        type="error"
        closable
        class="ma-4"
        @click:close="wallet.error = null"
      >
        {{ wallet.error }}
      </v-alert>

      <!-- Route guard banner: unregistered or inactive -->
      <v-alert
        v-if="routeReason"
        type="warning"
        class="ma-4"
        closable
        @click:close="clearRouteReason"
      >
        {{ routeReasonMessage }}
      </v-alert>

      <router-view />
    </v-main>

    <!-- ── Global Toast ────────────────────────────────────────────── -->
    <v-snackbar
      v-model="toast.visible"
      :color="toast.color"
      timer="top"
      :timeout="4000"
      rounded="lg"
      location="bottom right"
    >
      {{ toast.message }}
      <template #actions>
        <v-btn variant="text" icon="mdi-close" size="small" @click="toast.visible = false" />
      </template>
    </v-snackbar>
  </v-app>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useWalletStore } from '@/stores/wallet'
import { useUserRole } from '@/composables/useUserRole'
import { useToastStore } from '@/stores/toast'
import WalletConnect from '@/components/common/WalletConnect.vue'
import RoleBadge from '@/components/common/RoleBadge.vue'

const toast = useToastStore()

const drawer = ref(false)
const wallet = useWalletStore()
const { roleLabel } = useUserRole()
const route = useRoute()
const router = useRouter()

const navLinks = [
  { to: '/dashboard', label: 'Dashboard', icon: 'mdi-view-dashboard' },
  { to: '/search',    label: 'Search',    icon: 'mdi-magnify' },
]

const routeReason = computed(() => route.query.reason ?? null)
const routeReasonMessage = computed(() => {
  switch (routeReason.value) {
    case 'unregistered': return 'Your address is not registered in the system. Contact an admin.'
    case 'inactive':     return 'Your account has been deactivated. Contact an admin.'
    case 'error':        return 'Could not verify your account. Make sure you are connected to Anvil.'
    default:             return ''
  }
})

function clearRouteReason() {
  router.replace({ query: {} })
}

// Re-run the route guard after account switch — watch contract (set after connect() resolves)
watch(() => wallet.contract, (contract) => {
  if (contract && route.meta.requiresAuth) {
    router.replace(route.fullPath)
  }
})
</script>

