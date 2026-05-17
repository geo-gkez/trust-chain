<template>
  <v-container class="text-center d-flex flex-column align-center justify-center fill-height" style="max-width: 600px">

    <v-icon icon="mdi-link-variant" size="72" color="primary" class="mb-6" />

    <h1 class="text-h3 font-weight-bold mb-4">TrustChain</h1>

    <p class="text-body-1 text-medium-emphasis mb-8">
      End-to-end supply chain traceability on the blockchain.
      Connect your wallet to track, transfer, and certify product batches.
    </p>

    <v-alert
      v-if="reason === 'unregistered'"
      type="warning"
      variant="tonal"
      class="mb-6 text-left"
    >
      You need to connect your wallet to access that page.
    </v-alert>

    <WalletConnect v-if="!wallet.isConnected" />

  </v-container>
</template>

<script setup>
import { computed, watchEffect } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useWalletStore } from '@/stores/wallet'
import WalletConnect from '@/components/common/WalletConnect.vue'

const wallet = useWalletStore()
const router = useRouter()
const route  = useRoute()

const reason = computed(() => route.query.reason)

watchEffect(() => {
  if (wallet.isConnected) {
    router.push('/dashboard')
  }
})
</script>
