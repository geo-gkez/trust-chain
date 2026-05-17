<template>
  <div>
    <v-progress-circular v-if="loading" indeterminate color="primary" class="ma-4" />
    <v-row v-else>
      <v-col v-for="b in batches" :key="b.serialNumber" cols="12" md="6">
        <BatchCard :batch="b" />
      </v-col>
      <v-col v-if="!batches.length" cols="12">
        <v-alert type="info" variant="tonal">No batches found.</v-alert>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
import BatchCard from '@/components/batch/BatchCard.vue'

defineProps({
  batches: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
})
</script>
