<template>
  <v-container class="py-8" max-width="640">
    <h2 class="mb-6">Search Batch</h2>

    <v-text-field
      v-model="query"
      label="Serial Number"
      placeholder="BATCH-001"
      prepend-inner-icon="mdi-barcode-scan"
      clearable
      @keyup.enter="search"
      @click:clear="reset"
    >
      <template #append-inner>
        <v-btn
          color="primary"
          size="small"
          variant="tonal"
          :loading="loading"
          @click="search"
        >
          Search
        </v-btn>
      </template>
    </v-text-field>

    <!-- Not found -->
    <v-alert v-if="notFound" type="warning" variant="tonal" class="mt-4">
      No batch found with serial number <strong>{{ lastQuery }}</strong>.
    </v-alert>

    <!-- Result -->
    <div v-if="result" class="mt-4">
      <BatchCard :batch="result" />
      <v-btn
        class="mt-3"
        color="primary"
        variant="tonal"
        :to="`/batch/${result.serialNumber}`"
        append-icon="mdi-arrow-right"
      >
        View Full Details
      </v-btn>
    </div>
  </v-container>
</template>

<script setup>
import { ref } from 'vue'
import { useBatches } from '@/composables/useBatches'
import { useToastStore } from '@/stores/toast'
import BatchCard from '@/components/batch/BatchCard.vue'

const { fetchBatch } = useBatches()
const toast = useToastStore()

const query    = ref('')
const result   = ref(null)
const notFound = ref(false)
const loading  = ref(false)
const lastQuery = ref('')

function reset() {
  result.value   = null
  notFound.value = false
}

async function search() {
  const serial = query.value.trim()
  if (!serial) return

  reset()
  loading.value  = true
  lastQuery.value = serial

  try {
    const batch = await fetchBatch(serial)
    if (!batch.serialNumber) {
      notFound.value = true
    } else {
      result.value = batch
    }
  } catch (err) {
    toast.show(err?.shortMessage ?? err?.message ?? 'Search failed.', 'error')
  } finally {
    loading.value = false
  }
}
</script>
