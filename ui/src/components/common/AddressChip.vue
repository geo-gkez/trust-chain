<template>
  <v-tooltip :text="address" location="top">
    <template #activator="{ props: tip }">
      <span v-bind="tip" class="font-mono text-caption cursor-help">
        {{ short }}
      </span>
    </template>
  </v-tooltip>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  address: { type: String, default: '' },
})

const short = computed(() => {
  if (!props.address) return '—'
  return `${props.address.slice(0, 6)}…${props.address.slice(-4)}`
})
</script>
