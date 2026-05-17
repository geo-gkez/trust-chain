<template>
  <div>
    <v-progress-circular v-if="loading" indeterminate color="primary" class="ma-4" />

    <template v-else>
      <!-- Filters -->
      <v-row dense align="center" class="mb-2">
        <v-col cols="12" sm="5">
          <v-select
            v-model="selectedStatuses"
            :items="STATUS_LABELS"
            label="Status"
            multiple
            chips
            closable-chips
            clearable
            density="compact"
            variant="outlined"
            hide-details
          >
            <template #chip="{ item, props }">
              <v-chip
                v-bind="props"
                :color="STATUS_COLORS[item.value]"
                variant="tonal"
                size="x-small"
              />
            </template>
          </v-select>
        </v-col>

        <v-col cols="12" sm="5">
          <v-btn-toggle v-model="certifiedFilter" density="compact" variant="tonal" divided mandatory>
            <v-btn value="all"  size="small">All</v-btn>
            <v-btn value="yes"  size="small" color="teal">Certified</v-btn>
            <v-btn value="no"   size="small" color="orange">Uncertified</v-btn>
          </v-btn-toggle>
        </v-col>

        <v-col cols="12" sm="2" class="text-right">
          <v-chip size="x-small" variant="outlined">
            {{ filtered.length }} / {{ batches.length }}
          </v-chip>
        </v-col>
      </v-row>

      <!-- Grid -->
      <v-row>
        <v-col v-for="b in filtered" :key="b.serialNumber" cols="12" md="6">
          <BatchCard :batch="b" />
        </v-col>
        <v-col v-if="!filtered.length" cols="12">
          <v-alert type="info" variant="tonal">No batches match the current filter.</v-alert>
        </v-col>
      </v-row>
    </template>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import BatchCard from '@/components/batch/BatchCard.vue'
import { STATUSES, STATUS_COLORS } from '@/composables/useBatches'

const props = defineProps({
  batches: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
})

const STATUS_LABELS = Object.values(STATUSES)

const selectedStatuses = ref([])
const certifiedFilter  = ref('all')

const filtered = computed(() => {
  let list = props.batches
  if (selectedStatuses.value.length)
    list = list.filter(b => selectedStatuses.value.includes(b.statusLabel))
  if (certifiedFilter.value === 'yes') list = list.filter(b => b.certified)
  if (certifiedFilter.value === 'no')  list = list.filter(b => !b.certified)
  return list
})
</script>
