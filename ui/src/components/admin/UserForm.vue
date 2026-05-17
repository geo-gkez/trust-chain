<template>
  <v-form @submit.prevent="submit">
    <v-text-field
      v-model="form.address"
      label="Wallet Address"
      placeholder="0x..."
      prepend-inner-icon="mdi-wallet"
      class="mb-2"
    />
    <v-text-field
      v-model="form.name"
      label="Name"
      placeholder="e.g. Acme Logistics"
      prepend-inner-icon="mdi-account"
      class="mb-2"
    />
    <v-select
      v-model="form.role"
      :items="roleItems"
      label="Role"
      prepend-inner-icon="mdi-shield-account"
      class="mb-4"
    />
    <v-btn
      type="submit"
      color="primary"
      :loading="loading"
      :disabled="!form.address || !form.name || form.role === null"
      block
    >
      Register User
    </v-btn>
  </v-form>
</template>

<script setup>
import { ref } from 'vue'
import { useAdmin } from '@/composables/useAdmin'
import { useToastStore } from '@/stores/toast'
import { ROLES } from '@/composables/useUserRole'

const emit = defineEmits(['registered'])

const { registerUser } = useAdmin()
const toast = useToastStore()

const roleItems = Object.entries(ROLES).map(([value, title]) => ({
  title,
  value: Number(value),
}))

const form = ref({ address: '', name: '', role: null })
const loading = ref(false)

async function submit() {
  loading.value = true
  try {
    await registerUser(form.value.address, form.value.name, form.value.role)
    toast.show(`${form.value.name} registered successfully.`, 'success')
    form.value = { address: '', name: '', role: null }
    emit('registered')
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    loading.value = false
  }
}
</script>
