<template>
  <v-container class="py-8">
    <v-btn to="/search" variant="text" prepend-icon="mdi-arrow-left" class="mb-4">
      Back to Search
    </v-btn>

    <!-- Loading skeleton -->
    <v-skeleton-loader v-if="loading" type="heading, paragraph, card" />

    <v-alert v-else-if="!batch" type="warning" variant="tonal" class="ma-4">
      Batch "<strong>{{ serial }}</strong>" not found.
    </v-alert>

    <template v-else>
      <!-- ── Header ─────────────────────────────────────────────────── -->
      <v-row class="mb-2" align="center">
        <v-col>
          <h2 class="text-h5 font-weight-bold">{{ batch.serialNumber }}</h2>
          <div class="text-medium-emphasis text-body-2">{{ batch.origin }} · {{ productTypeName }}</div>
        </v-col>
        <v-col cols="auto" class="d-flex gap-2 flex-wrap">
          <v-chip :color="statusColor" variant="tonal" label size="small">{{ batch.status }}</v-chip>
          <v-chip v-if="batch.certified" color="success" variant="tonal" label size="small" prepend-icon="mdi-check-decagram">Certified</v-chip>
          <v-chip v-if="batch.recalled"  color="error"   variant="tonal" label size="small" prepend-icon="mdi-alert">Recalled</v-chip>
        </v-col>
      </v-row>

      <!-- ── Lifecycle Stepper ──────────────────────────────────────── -->
      <v-card color="surface-variant" rounded="lg" flat class="mb-6 pa-2">
        <v-stepper
          :model-value="Math.min(batch.statusNum, 3)"
          non-linear
          flat
          hide-actions
          alt-labels
          bg-color="transparent"
        >
          <v-stepper-header>
            <v-stepper-item
              title="Produced"
              :value="0"
              :complete="batch.statusNum > 0"
              icon="mdi-factory"
              color="primary"
            />
            <v-divider />
            <v-stepper-item
              title="Stored"
              :value="1"
              :complete="batch.statusNum > 1"
              icon="mdi-warehouse"
              color="primary"
            />
            <v-divider />
            <v-stepper-item
              title="In Transit"
              :value="2"
              :complete="batch.statusNum > 2"
              icon="mdi-truck"
              color="primary"
            />
            <v-divider />
            <v-stepper-item
              title="Distributed"
              :value="3"
              :complete="batch.statusNum >= 3"
              icon="mdi-store"
              color="primary"
            />
          </v-stepper-header>
        </v-stepper>

        <!-- Special state banners for terminal reverse-chain states -->
        <div v-if="batch.recalled || batch.statusNum >= 4" class="d-flex justify-center gap-2 pb-2">
          <v-chip
            v-if="batch.statusNum === 4 || batch.recalled"
            color="red"
            variant="tonal"
            prepend-icon="mdi-alert-octagon"
            size="small"
          >
            RECALLED
          </v-chip>
          <v-chip
            v-if="batch.statusNum === 5"
            color="deep-purple"
            variant="tonal"
            prepend-icon="mdi-delete-alert"
            size="small"
          >
            DISPOSED
          </v-chip>
        </div>
      </v-card>

      <v-row>
        <!-- ── Batch Details Card ──────────────────────────────────── -->
        <v-col cols="12" md="5">
          <v-card color="surface-variant" rounded="lg">
            <v-card-title class="text-body-1 font-weight-bold pa-4">Batch Details</v-card-title>
            <v-divider />
            <v-list bg-color="transparent" density="compact">
              <v-list-item>
                <template #prepend><v-icon icon="mdi-tag" size="18" color="primary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Product Type</v-list-item-title>
                <v-list-item-subtitle>{{ productTypeName }}</v-list-item-subtitle>
              </v-list-item>

              <v-list-item>
                <template #prepend><v-icon icon="mdi-shape" size="18" color="primary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Category</v-list-item-title>
                <v-list-item-subtitle>{{ batch.category }}</v-list-item-subtitle>
              </v-list-item>

              <v-list-item>
                <template #prepend><v-icon icon="mdi-numeric" size="18" color="primary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Quantity</v-list-item-title>
                <v-list-item-subtitle>{{ batch.quantity }} {{ unitName }}</v-list-item-subtitle>
              </v-list-item>

              <v-list-item>
                <template #prepend><v-icon icon="mdi-map-marker" size="18" color="primary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Origin</v-list-item-title>
                <v-list-item-subtitle>{{ batch.origin }}</v-list-item-subtitle>
              </v-list-item>

              <v-list-item>
                <template #prepend><v-icon icon="mdi-calendar-plus" size="18" color="primary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Created</v-list-item-title>
                <v-list-item-subtitle>{{ formatDate(batch.creationDate, true) }}</v-list-item-subtitle>
              </v-list-item>

              <v-list-item>
                <template #prepend><v-icon icon="mdi-calendar-clock" size="18" color="primary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Expiry</v-list-item-title>
                <v-list-item-subtitle>{{ batch.expiryDate ? formatDate(batch.expiryDate, true) : 'No expiry' }}</v-list-item-subtitle>
              </v-list-item>

              <v-divider class="my-2" />

              <v-list-item>
                <template #prepend><v-icon icon="mdi-factory" size="18" color="secondary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Producer</v-list-item-title>
                <v-list-item-subtitle>
                  <AddressChip :address="batch.producer" />
                </v-list-item-subtitle>
              </v-list-item>

              <v-list-item>
                <template #prepend><v-icon icon="mdi-account-arrow-right" size="18" color="secondary" class="mr-2" /></template>
                <v-list-item-title class="text-caption text-medium-emphasis">Current Holder</v-list-item-title>
                <v-list-item-subtitle>
                  <AddressChip :address="batch.currentHolder" />
                </v-list-item-subtitle>
              </v-list-item>
            </v-list>
          </v-card>
        </v-col>

        <!-- ── Timeline ───────────────────────────────────────────── -->
        <v-col cols="12" md="7">
          <v-card color="surface-variant" rounded="lg">
            <v-card-title class="text-body-1 font-weight-bold pa-4">
              <v-icon icon="mdi-timeline" class="mr-2" />
              Route Timeline
            </v-card-title>
            <v-divider />
            <v-card-text>
              <BatchTimeline :serial-number="batch.serialNumber" />
            </v-card-text>
          </v-card>
        </v-col>
      </v-row>
    </template>
  </v-container>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useBatches, STATUS_COLORS } from '@/composables/useBatches'
import { useAdmin } from '@/composables/useAdmin'
import { formatDate } from '@/utils/format'
import BatchTimeline from '@/components/batch/BatchTimeline.vue'
import AddressChip from '@/components/common/AddressChip.vue'

const route  = useRoute()
const serial = computed(() => route.params.serial)

const { fetchBatch, loading } = useBatches()
const admin = useAdmin()

const batch        = ref(null)
const productTypes = ref([])
const units        = ref([])

onMounted(async () => {
  ;[productTypes.value, units.value, batch.value] = await Promise.all([
    admin.getProductTypes(),
    admin.getUnits(),
    fetchBatch(serial.value),
  ])
})

const productTypeName = computed(() => productTypes.value[batch.value?.productTypeId] ?? '—')
const unitName        = computed(() => units.value[batch.value?.unitId] ?? '—')
const statusColor     = computed(() => STATUS_COLORS[batch.value?.status] ?? 'grey')


</script>
