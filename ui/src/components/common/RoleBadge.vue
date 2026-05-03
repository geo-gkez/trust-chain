<template>
  <v-chip
    :color="color"
    size="small"
    variant="tonal"
    :prepend-icon="icon"
    label
  >
    {{ role }}
  </v-chip>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  role: { type: String, required: true },
})

const ROLE_META = {
  ADMIN:       { color: 'red',    icon: 'mdi-shield-crown' },
  PRODUCER:    { color: 'green',  icon: 'mdi-factory' },
  TRANSPORTER: { color: 'blue',   icon: 'mdi-truck' },
  WAREHOUSE:   { color: 'orange', icon: 'mdi-warehouse' },
  DISTRIBUTOR: { color: 'cyan',   icon: 'mdi-store' },
  AUDITOR:     { color: 'purple', icon: 'mdi-magnify-scan' },
}

const color = computed(() => ROLE_META[props.role]?.color ?? 'grey')
const icon  = computed(() => ROLE_META[props.role]?.icon  ?? 'mdi-account')
</script>
