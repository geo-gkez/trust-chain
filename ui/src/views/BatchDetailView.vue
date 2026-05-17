<template>
  <v-container class="py-8">

    <!-- Loading -->
    <v-progress-circular v-if="loading" indeterminate color="primary" class="ma-8" />

    <!-- Not found -->
    <v-alert v-else-if="notFound" type="warning" variant="tonal">
      No batch found with serial number <strong>{{ serial }}</strong>.
    </v-alert>

    <template v-else-if="batch">

      <!-- Header -->
      <div class="d-flex align-center flex-wrap ga-2 mb-4">
        <h2>{{ batch.serialNumber }}</h2>
        <v-chip :color="batch.statusColor" variant="tonal">{{ batch.statusLabel }}</v-chip>
        <v-chip v-if="batch.certified" color="green" variant="tonal" prepend-icon="mdi-check-decagram">Certified</v-chip>
        <v-chip v-if="batch.recalled"  color="red"   variant="tonal" prepend-icon="mdi-alert-circle">Recalled</v-chip>
      </div>

      <!-- Expiry warning banner -->
      <v-alert
        v-if="isExpired"
        type="error"
        variant="tonal"
        class="mb-4"
        icon="mdi-clock-alert"
      >
        This batch expired on {{ expiryFormatted }}.
      </v-alert>
      <v-alert
        v-else-if="isNearExpiry"
        type="warning"
        variant="tonal"
        class="mb-4"
        icon="mdi-clock-alert-outline"
      >
        This batch expires on {{ expiryFormatted }} — within 7 days.
      </v-alert>

      <!-- Two columns -->
      <v-row>
        <!-- Left: Batch details -->
        <v-col cols="12" md="5">
          <v-card class="pa-4">
            <v-card-title class="mb-2">Batch Details</v-card-title>
            <v-table density="compact">
              <tbody>
                <tr><td class="text-medium-emphasis">Origin</td><td>{{ batch.origin || '—' }}</td></tr>
                <tr><td class="text-medium-emphasis">Category</td><td>{{ batch.categoryLabel }}</td></tr>
                <tr><td class="text-medium-emphasis">Quantity</td><td>{{ batch.quantity }}</td></tr>
                <tr><td class="text-medium-emphasis">Producer</td><td class="text-caption">{{ batch.producer }}</td></tr>
                <tr><td class="text-medium-emphasis">Current Holder</td><td class="text-caption">{{ batch.currentHolder }}</td></tr>
                <tr v-if="batch.expiryDate"><td class="text-medium-emphasis">Expiry</td><td>{{ expiryFormatted }}</td></tr>
              </tbody>
            </v-table>
          </v-card>
        </v-col>

        <!-- Right: Timeline -->
        <v-col cols="12" md="7">
          <v-card class="pa-4">
            <v-card-title class="mb-2">Route Timeline</v-card-title>
            <v-progress-circular v-if="loadingTimeline" indeterminate color="primary" class="ma-4" />
            <BatchTimeline v-else :entries="timeline" />
          </v-card>
        </v-col>
      </v-row>

    </template>

  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useBatches } from '@/composables/useBatches'
import { useToastStore } from '@/stores/toast'
import BatchTimeline from '@/components/batch/BatchTimeline.vue'

const route = useRoute()
const { fetchBatch, fetchBatchTimeline } = useBatches()
const toast = useToastStore()

const serial  = computed(() => route.params.serial)
const batch   = ref(null)
const timeline = ref([])
const loading  = ref(true)
const loadingTimeline = ref(true)
const notFound = ref(false)

const now       = Math.floor(Date.now() / 1000)
const sevenDays = 7 * 24 * 3600

const isExpired    = computed(() => batch.value?.expiryDate && batch.value.expiryDate < now)
const isNearExpiry = computed(() => batch.value?.expiryDate && !isExpired.value && (batch.value.expiryDate - now) < sevenDays)
const expiryFormatted = computed(() =>
  batch.value?.expiryDate ? new Date(batch.value.expiryDate * 1000).toLocaleDateString() : null
)

onMounted(async () => {
  const [batchResult, timelineResult] = await Promise.allSettled([
    fetchBatch(serial.value),
    fetchBatchTimeline(serial.value),
  ])

  loading.value = false
  loadingTimeline.value = false

  if (batchResult.status === 'fulfilled') {
    if (!batchResult.value.serialNumber) {
      notFound.value = true
    } else {
      batch.value = batchResult.value
    }
  } else {
    toast.show('Failed to load batch.', 'error')
  }

  if (timelineResult.status === 'fulfilled') {
    timeline.value = timelineResult.value
  }
})
</script>
