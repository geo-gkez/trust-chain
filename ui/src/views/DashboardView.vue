<template>
  <v-container class="py-8">
    <h2>Dashboard</h2>
    <p class="mt-4 text-medium-emphasis">Product types: {{ productTypes }}</p>
  </v-container>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useWalletStore } from '@/stores/wallet'

const wallet       = useWalletStore()
const productTypes = ref([])

onMounted(async () => {
  productTypes.value = await wallet.contract.getProductTypes()
  console.log('getProductTypes() →', productTypes.value)
})
</script>
