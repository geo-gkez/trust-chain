<template>
  <v-card-text>
    <p class="text-subtitle-2 mb-3">{{ label }}</p>
    <v-text-field
      v-model="serial"
      label="Serial Number"
      variant="outlined"
      density="compact"
      prepend-inner-icon="mdi-barcode"
      class="mb-2"
    />
    <v-text-field
      v-model="location"
      label="Location"
      variant="outlined"
      density="compact"
      prepend-inner-icon="mdi-map-marker"
      class="mb-2"
    />
    <v-btn
      :color="color"
      :loading="loading"
      :prepend-icon="icon"
      :disabled="!serial.trim() || !location.trim()"
      @click="execute"
    >
      {{ label }}
    </v-btn>
  </v-card-text>
</template>

<script setup>
import { ref } from 'vue'
import { useBatches } from '@/composables/useBatches'

const props = defineProps({
  action: { type: String, required: true },
  label:  { type: String, required: true },
  icon:   { type: String, default: 'mdi-swap-horizontal' },
  color:  { type: String, default: 'primary' },
})

const emit = defineEmits(['done'])

const batches  = useBatches()
const { loading } = batches
const serial   = ref('')
const location = ref('')

async function execute() {
  const s = serial.value.trim()
  const l = location.value.trim()
  if (!s || !l) return
  const ok = await batches[props.action](s, l)
  if (ok) {
    serial.value   = ''
    location.value = ''
    emit('done')
  }
}
</script>
