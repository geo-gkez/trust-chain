<template>
  <v-btn
    :color="wallet.isConnected ? 'success' : 'primary'"
    :loading="wallet.isConnecting"
    variant="tonal"
    @click="wallet.isConnected ? wallet.disconnect() : wallet.connect()"
  >
    <v-icon icon="mdi-wallet" class="mr-2" />
    {{ wallet.isConnected ? wallet.shortAddress : 'Connect Wallet' }}
  </v-btn>
</template>

<script setup>
import { useWalletStore } from '@/stores/wallet'

const wallet = useWalletStore()
</script>
