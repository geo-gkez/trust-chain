<template>
  <v-form @submit.prevent="submit">
    <v-text-field
      v-model="serial"
      label="Serial Number"
      placeholder="BATCH-001"
      class="mb-2"
    />
    <v-text-field
      v-model="location"
      label="Location"
      placeholder="GR-ATH-WAREHOUSE"
      class="mb-4"
    />
    <v-btn type="submit" color="primary" :loading="loading" block>
      {{ label }}
    </v-btn>
  </v-form>
</template>

<script setup>
import { ref } from 'vue'
import { useToastStore } from '@/stores/toast'

const props = defineProps({
  label: { type: String, default: 'Submit' },
  fn:    { type: Function, required: true },
})
const emit = defineEmits(['done'])

const toast    = useToastStore()
const serial   = ref('')
const location = ref('')
const loading  = ref(false)

async function submit() {
  loading.value = true
  try {
    await props.fn(serial.value, location.value)
    toast.show('Action completed.', 'success')
    serial.value = ''
    location.value = ''
    emit('done')
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    loading.value = false
  }
}
</script>
