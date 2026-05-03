<template>
  <v-btn
    :color="wallet.isConnected ? 'error' : 'primary'"
    :loading="wallet.isConnecting"
    :block="block"
    variant="tonal"
    @click="toggle"
  >
    <v-icon :icon="wallet.isConnected ? 'mdi-wallet-off' : 'mdi-wallet'" class="mr-1" />
    <span v-if="wallet.isConnected">{{ wallet.shortAddress }}</span>
    <span v-else>Connect Wallet</span>
  </v-btn>
</template>

<script setup>
import { useWalletStore } from '@/stores/wallet'

defineProps({
  block: { type: Boolean, default: false },
})

const wallet = useWalletStore()

function toggle() {
  if (wallet.isConnected) {
    wallet.disconnect()
  } else {
    wallet.connect()
  }
}
</script>
