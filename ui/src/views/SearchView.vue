<template>
  <v-container class="py-8">
    <v-row justify="center">
      <v-col cols="12" md="8">
        <h2 class="text-h5 font-weight-bold mb-6">
          <v-icon icon="mdi-magnify" class="mr-2" />
          Search Batch
        </h2>

        <!-- Search input -->
        <v-text-field
          v-model="query"
          label="Serial Number"
          placeholder="OLIVE-GR-001"
          prepend-inner-icon="mdi-barcode"
          variant="outlined"
          clearable
          @keyup.enter="search"
        >
          <template #append-inner>
            <v-btn
              icon="mdi-magnify"
              variant="text"
              :loading="loading"
              @click="search"
            />
          </template>
        </v-text-field>

        <v-alert v-if="notFound" type="warning" variant="tonal" class="mb-4">
          No batch found for serial "<strong>{{ lastQuery }}</strong>".
        </v-alert>

        <!-- Result -->
        <BatchCard
          v-if="batch"
          :batch="batch"
          :product-types="productTypes"
          :units="units"
          :link-to="`/batch/${batch.serialNumber}`"
          class="mb-4"
        />

        <div v-if="batch" class="d-flex justify-end">
          <v-btn
            :to="`/batch/${batch.serialNumber}`"
            color="secondary"
            variant="tonal"
            append-icon="mdi-arrow-right"
          >
            View Full Details
          </v-btn>
        </div>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useBatches } from '@/composables/useBatches'
import { useAdmin } from '@/composables/useAdmin'
import BatchCard from '@/components/batch/BatchCard.vue'

const { fetchBatch, loading } = useBatches()
const admin = useAdmin()

const query     = ref('')
const lastQuery = ref('')
const batch     = ref(null)
const notFound  = ref(false)
const productTypes = ref([])
const units        = ref([])

onMounted(async () => {
  productTypes.value = await admin.getProductTypes()
  units.value        = await admin.getUnits()
})

async function search() {
  const q = query.value?.trim()
  if (!q) return
  notFound.value  = false
  batch.value     = null
  lastQuery.value = q
  const result    = await fetchBatch(q)
  if (!result) {
    notFound.value = true
  } else {
    batch.value = result
  }
}
</script>
