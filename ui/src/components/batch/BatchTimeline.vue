<template>
  <v-skeleton-loader v-if="loading" type="list-item-two-line@4" />

  <v-alert v-else-if="!events.length" type="info" variant="tonal">
    No timeline events found for this batch.
  </v-alert>

  <v-timeline v-else align="start" side="end" density="compact">
    <v-timeline-item
      v-for="(evt, idx) in events"
      :key="idx"
      :dot-color="dotColor(evt)"
      :icon="dotIcon(evt)"
      size="small"
    >
      <template #opposite>
        <div class="text-caption text-medium-emphasis text-right">
          <div>{{ formatDate(evt.at, true) }}</div>
          <div>Block {{ evt.block }}</div>
        </div>
      </template>

      <v-card color="surface-variant" rounded="lg" class="mb-2">
        <v-card-item class="pb-1">
          <v-card-title class="text-body-2 font-weight-bold">
            <template v-if="evt.type === 'created'">
              Batch Created
            </template>
            <template v-else>
              <v-chip :color="statusColor(evt.from)" size="x-small" label variant="tonal" class="mr-1">
                {{ evt.from }}
              </v-chip>
              <v-icon icon="mdi-arrow-right" size="14" class="mx-1" />
              <v-chip :color="statusColor(evt.to)" size="x-small" label variant="tonal">
                {{ evt.to }}
              </v-chip>
            </template>
          </v-card-title>
        </v-card-item>

        <v-card-text class="pt-0 text-caption">
          <div v-if="evt.type === 'created'" class="d-flex align-center gap-1">
            <v-icon icon="mdi-account" size="14" />
            Producer: <AddressChip :address="evt.producer" />
          </div>
          <template v-else>
            <div v-if="evt.location" class="d-flex align-center gap-1">
              <v-icon icon="mdi-map-marker" size="14" />
              {{ evt.location }}
            </div>
            <div class="d-flex align-center gap-1">
              <v-icon icon="mdi-account" size="14" />
              <AddressChip :address="evt.by" />
            </div>
          </template>
          <div class="mt-1 text-secondary">{{ shortHash(evt.txHash) }}</div>
        </v-card-text>
      </v-card>
    </v-timeline-item>
  </v-timeline>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useBatches, STATUS_COLORS } from '@/composables/useBatches'
import { formatDate } from '@/utils/format'
import AddressChip from '@/components/common/AddressChip.vue'

const props = defineProps({
  serialNumber: { type: String, required: true },
})

const { fetchBatchTimeline, loading } = useBatches()
const events = ref([])

watch(
  () => props.serialNumber,
  async (serial) => {
    if (serial) events.value = await fetchBatchTimeline(serial)
  },
  { immediate: true }
)

function dotColor(evt) {
  if (evt.type === 'created') return 'primary'
  return STATUS_COLORS[evt.to] ?? 'grey'
}

function dotIcon(evt) {
  if (evt.type === 'created') return 'mdi-star'
  const icons = {
    STORED:      'mdi-warehouse',
    IN_TRANSIT:  'mdi-truck',
    DISTRIBUTED: 'mdi-store',
    RECALLED:    'mdi-alert',
    DISPOSED:    'mdi-delete',
  }
  return icons[evt.to] ?? 'mdi-circle'
}

function statusColor(status) {
  return STATUS_COLORS[status] ?? 'grey'
}

function shortHash(hash) {
  if (!hash) return ''
  return `${hash.slice(0, 10)}…`
}
</script>
