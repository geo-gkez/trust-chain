<template>
  <v-card
    :to="linkTo"
    :hover="!!linkTo"
    color="surface-variant"
    rounded="lg"
  >
    <v-card-item>
      <template #prepend>
        <v-icon :icon="categoryIcon" size="32" color="secondary" />
      </template>

      <v-card-title class="text-body-1 font-weight-bold">
        {{ batch.serialNumber }}
      </v-card-title>

      <v-card-subtitle>
        {{ productTypeName }} · {{ batch.origin }}
      </v-card-subtitle>

      <template #append>
        <v-chip
          :color="statusColor"
          size="small"
          variant="tonal"
          label
        >
          {{ batch.status }}
        </v-chip>
      </template>
    </v-card-item>

    <v-card-text class="pt-0">
      <v-row dense>
        <v-col cols="6">
          <span class="text-medium-emphasis text-caption">Qty</span>
          <div class="text-body-2">{{ batch.quantity }} {{ unitName }}</div>
        </v-col>
        <v-col cols="6">
          <span class="text-medium-emphasis text-caption">Category</span>
          <div class="text-body-2">{{ batch.category }}</div>
        </v-col>
        <v-col cols="6">
          <span class="text-medium-emphasis text-caption">Created</span>
          <div class="text-body-2">{{ formatDate(batch.creationDate) }}</div>
        </v-col>
        <v-col cols="6">
          <span class="text-medium-emphasis text-caption">Holder</span>
          <div class="text-body-2 text-truncate">{{ shortAddr(batch.currentHolder) }}</div>
        </v-col>
      </v-row>

      <div class="mt-2 d-flex gap-2">
        <v-chip v-if="batch.certified" color="success" size="x-small" prepend-icon="mdi-check-decagram">
          Certified
        </v-chip>
        <v-chip v-if="batch.recalled" color="error" size="x-small" prepend-icon="mdi-alert">
          Recalled
        </v-chip>
      </div>
    </v-card-text>
  </v-card>
</template>

<script setup>
import { computed } from 'vue'
import { STATUS_COLORS, CATEGORY_LABELS } from '@/composables/useBatches'
import { formatDate } from '@/utils/format'

const props = defineProps({
  batch:        { type: Object, required: true },
  productTypes: { type: Array,  default: () => [] }, // string[]
  units:        { type: Array,  default: () => [] }, // string[]
  linkTo:       { type: [String, Object], default: null },
})

const statusColor   = computed(() => STATUS_COLORS[props.batch.status] ?? 'grey')
const productTypeName = computed(() => props.productTypes[props.batch.productTypeId] ?? `#${props.batch.productTypeId}`)
const unitName        = computed(() => props.units[props.batch.unitId] ?? `#${props.batch.unitId}`)

const CATEGORY_ICONS = {
  PERISHABLE:     'mdi-leaf',
  REFRIGERATED:   'mdi-snowflake',
  HAZARDOUS:      'mdi-biohazard',
  NON_PERISHABLE: 'mdi-package-variant',
  FRAGILE:        'mdi-glass-fragile',
  OTHER:          'mdi-cube-outline',
}

const categoryIcon = computed(() => CATEGORY_ICONS[props.batch.category] ?? 'mdi-cube-outline')

function shortAddr(addr) {
  if (!addr) return '—'
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}
</script>
