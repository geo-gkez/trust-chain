<template>
  <v-form ref="formRef" @submit.prevent="submit">
    <v-row>
      <v-col cols="12">
        <v-text-field
          v-model="form.address"
          label="Ethereum Address"
          placeholder="0x..."
          prepend-inner-icon="mdi-ethereum"
          :rules="[rules.required, rules.address]"
          variant="outlined"
        />
      </v-col>

      <v-col cols="12" md="6">
        <v-text-field
          v-model="form.name"
          label="Display Name"
          placeholder="Athens Producer"
          prepend-inner-icon="mdi-account-tag"
          :rules="[rules.required, rules.bytes32]"
          variant="outlined"
        />
      </v-col>

      <v-col cols="12" md="6">
        <v-select
          v-model="form.role"
          :items="roleItems"
          label="Role"
          prepend-inner-icon="mdi-shield-account"
          :rules="[rules.required]"
          variant="outlined"
        />
      </v-col>
    </v-row>

    <div class="d-flex gap-2 justify-end">
      <v-btn variant="text" @click="reset">Clear</v-btn>
      <v-btn
        type="submit"
        color="primary"
        :loading="loading"
        prepend-icon="mdi-account-plus"
      >
        Register User
      </v-btn>
    </div>
  </v-form>
</template>

<script setup>
import { ref } from 'vue'
import { ethers } from 'ethers'
import { useAdmin } from '@/composables/useAdmin'
import { ROLES } from '@/composables/useUserRole'

const emit = defineEmits(['registered'])

const { registerUser, loading, error } = useAdmin()
const formRef = ref(null)

const form = ref({ address: '', name: '', role: null })

// Build role dropdown items from ROLES map (exclude ADMIN — only one admin, set at deploy)
const roleItems = Object.entries(ROLES)
  .filter(([num]) => num !== '5')
  .map(([num, label]) => ({
    title: label,
    value: Number(num),
  }))

const rules = {
  required: (v) => (v !== null && v !== '' && v !== undefined) || 'Required',
  address:  (v) => ethers.isAddress(v) || 'Invalid Ethereum address',
  bytes32:  (v) => v.length <= 31 || 'Max 31 characters',
}

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return

  const ok = await registerUser(form.value.address, form.value.name, form.value.role)
  if (ok) {
    emit('registered', form.value.address)
    reset()
  }
}

function reset() {
  formRef.value?.reset()
}
</script>
