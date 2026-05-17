<template>
  <v-container class="py-8">
    <h2>Dashboard</h2>
    <p class="mt-4 text-medium-emphasis">Users: {{ users }}</p>
  </v-container>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAdmin } from '@/composables/useAdmin'

const { fetchAllUsers } = useAdmin()
const users = ref([])

onMounted(async () => {
  users.value = await fetchAllUsers()
  console.log('fetchAllUsers() →', users.value)
})
</script>
