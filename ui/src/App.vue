<template>
  <v-app theme="trustChainTheme">

    <!-- ── Top Bar ──────────────────────────────────────────────────── -->
    <v-app-bar elevation="2" color="surface">
      <v-app-bar-nav-icon @click="drawer = !drawer" />
      <v-app-bar-title>
        <v-icon icon="mdi-link-variant" color="primary" class="mr-2" />
        <span class="font-weight-bold">TrustChain</span>
      </v-app-bar-title>
      <v-spacer />
      <WalletConnect class="mr-2" />
    </v-app-bar>

    <!-- ── Side Drawer ──────────────────────────────────────────────── -->
    <v-navigation-drawer v-model="drawer" temporary>
      <v-list-item
        prepend-icon="mdi-link-variant"
        title="TrustChain"
        subtitle="Supply Chain Traceability"
        nav
      />
      <v-divider />
      <v-list density="compact" nav>
        <v-list-item prepend-icon="mdi-view-dashboard" title="Dashboard" to="/dashboard" @click="drawer = false" />
        <v-list-item prepend-icon="mdi-magnify"        title="Search"    to="/search"    @click="drawer = false" />
      </v-list>
    </v-navigation-drawer>

    <!-- ── Main Content ─────────────────────────────────────────────── -->
    <v-main>
      <router-view />
    </v-main>

    <!-- ── Global Toast ─────────────────────────────────────────────── -->
    <v-snackbar
      v-model="toast.visible"
      :color="toast.color"
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
import { ref } from 'vue'
import { useToastStore } from '@/stores/toast'
import WalletConnect from '@/components/common/WalletConnect.vue'

const drawer = ref(false)
const toast  = useToastStore()
</script>
