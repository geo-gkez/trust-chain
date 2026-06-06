<template>
  <v-form @submit.prevent="submit">
    <v-text-field
      v-model="serial"
      label="Serial Number"
      placeholder="BATCH-001"
      class="mb-2"
    />
    <v-text-field
      v-model="recipient"
      label="Recipient Address"
      placeholder="0x..."
      prepend-inner-icon="mdi-wallet"
      class="mb-4"
    />
    <v-btn type="submit" color="warning" :loading="loading" block>
      Propose Hand-Off
    </v-btn>
  </v-form>
</template>

<script setup>
import { ref } from 'vue'
import { useBatches } from '@/composables/useBatches'
import { useToastStore } from '@/stores/toast'

const emit = defineEmits(['done'])

const { proposeCustody } = useBatches()
const toast     = useToastStore()
const serial    = ref('')
const recipient = ref('')
const loading   = ref(false)

async function submit() {
  loading.value = true
  try {
    await proposeCustody(serial.value, recipient.value)
    toast.show(`Hand-off of ${serial.value} proposed — waiting for the recipient to accept.`, 'success')
    serial.value    = ''
    recipient.value = ''
    emit('done')
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    loading.value = false
  }
}
</script>
