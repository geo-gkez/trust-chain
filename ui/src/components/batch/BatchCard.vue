<template>
  <v-card variant="outlined" class="pa-4">

    <!-- Header row -->
    <div class="d-flex align-center justify-space-between mb-3">
      <span class="font-weight-bold">{{ batch.serialNumber }}</span>
      <div class="d-flex ga-2">
        <v-chip v-if="isExpired"   color="error"   size="small" variant="tonal">Expired</v-chip>
        <v-chip v-else-if="isNearExpiry" color="warning" size="small" variant="tonal">Expires soon</v-chip>
        <v-chip :color="batch.statusColor" size="small" variant="tonal">{{ batch.statusLabel }}</v-chip>
        <v-chip v-if="batch.certified" color="teal" size="small" variant="tonal" prepend-icon="mdi-check-decagram">Certified</v-chip>
      </div>
    </div>

    <!-- Details -->
    <v-table density="compact" class="text-body-2">
      <tbody>
        <tr><td class="text-medium-emphasis">Origin</td>      <td>{{ batch.origin }}</td></tr>
        <tr><td class="text-medium-emphasis">Product Type</td><td>{{ batch.productTypeLabel || '—' }}</td></tr>
        <tr><td class="text-medium-emphasis">Quantity</td>    <td>{{ batch.quantity }}<span v-if="batch.unitLabel">&nbsp;{{ batch.unitLabel }}</span></td></tr>
        <tr><td class="text-medium-emphasis">Category</td>    <td>{{ batch.categoryLabel }}</td></tr>
        <tr><td class="text-medium-emphasis">Holder</td>      <td class="text-truncate" style="max-width:200px">{{ batch.currentHolder }}</td></tr>
        <tr v-if="batch.expiryDate">
          <td class="text-medium-emphasis">Expiry</td>
          <td>{{ expiryFormatted }}</td>
        </tr>
      </tbody>
    </v-table>

    <!-- Footer -->
    <div class="d-flex justify-end mt-3">
      <v-btn size="small" variant="text" :to="`/batch/${batch.serialNumber}`">
        View Details →
      </v-btn>
    </div>

  </v-card>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  batch: { type: Object, required: true },
})

const now       = Math.floor(Date.now() / 1000)
const sevenDays = 7 * 24 * 3600

const isExpired    = computed(() => props.batch.expiryDate && props.batch.expiryDate < now)
const isNearExpiry = computed(() => props.batch.expiryDate && !isExpired.value
  && (props.batch.expiryDate - now) < sevenDays)

const expiryFormatted = computed(() =>
  props.batch.expiryDate
    ? new Date(props.batch.expiryDate * 1000).toLocaleDateString()
    : null
)
</script>
