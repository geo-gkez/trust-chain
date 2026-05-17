<template>
  <v-timeline side="end" density="compact">

    <v-timeline-item
      v-for="(entry, i) in entries"
      :key="i"
      :dot-color="dotColor(entry)"
      size="small"
    >
      <!-- Created -->
      <template v-if="entry.type === 'created'">
        <div class="text-body-2 font-weight-bold">Batch Created</div>
        <div class="text-caption text-medium-emphasis">
          Producer: {{ short(entry.producer) }}
        </div>
        <div class="text-caption text-medium-emphasis">Block {{ entry.block }}</div>
      </template>

      <!-- Status transition -->
      <template v-else-if="entry.type === 'transitioned'">
        <div class="text-body-2 font-weight-bold d-flex align-center ga-1">
          <v-chip :color="statusColor(entry.from)" size="x-small" variant="tonal">{{ entry.from }}</v-chip>
          <v-icon size="x-small">mdi-arrow-right</v-icon>
          <v-chip :color="statusColor(entry.to)" size="x-small" variant="tonal">{{ entry.to }}</v-chip>
        </div>
        <div v-if="entry.location" class="text-caption text-medium-emphasis">
          Location: {{ entry.location }}
        </div>
        <div class="text-caption text-medium-emphasis">
          Actor: {{ short(entry.actor) }}
        </div>
        <div class="text-caption text-medium-emphasis">Block {{ entry.block }}</div>
      </template>

      <!-- Custody transfer -->
      <template v-else-if="entry.type === 'transferred'">
        <div class="text-body-2 font-weight-bold">Custody Transfer</div>
        <div class="text-caption text-medium-emphasis">
          {{ short(entry.from) }} → {{ short(entry.to) }}
        </div>
        <div class="text-caption text-medium-emphasis">Block {{ entry.block }}</div>
      </template>

    </v-timeline-item>

  </v-timeline>
</template>

<script setup>
import { STATUS_COLORS } from '@/composables/useBatches'

defineProps({
  entries: { type: Array, default: () => [] },
})

function short(addr) {
  if (!addr) return '—'
  return addr.slice(0, 6) + '…' + addr.slice(-4)
}

function statusColor(label) {
  return STATUS_COLORS[label] ?? 'grey'
}

function dotColor(entry) {
  if (entry.type === 'created')     return 'green'
  if (entry.type === 'transferred') return 'orange'
  return 'primary'
}
</script>
