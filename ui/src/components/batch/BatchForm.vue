<template>
  <v-form @submit.prevent="submit">
    <v-row>
      <v-col cols="12" sm="6">
        <v-text-field
          v-model="form.serial"
          label="Serial Number"
          placeholder="BATCH-001"
          :error-messages="submitted && !form.serial.trim() ? 'Required.' : ''"
        />
      </v-col>
      <v-col cols="12" sm="6">
        <v-text-field
          v-model="form.origin"
          label="Origin"
          placeholder="GR-ATH"
          :error-messages="submitted && !form.origin.trim() ? 'Required.' : ''"
        />
      </v-col>
      <v-col cols="12" sm="6">
        <v-select
          v-model="form.productTypeId"
          :items="productTypeItems"
          label="Product Type"
          :loading="loadingRegistries"
          :error-messages="submitted && form.productTypeId === null ? 'Required.' : ''"
        />
      </v-col>
      <v-col cols="12" sm="6">
        <v-select
          v-model="form.category"
          :items="categoryItems"
          label="Category"
          :error-messages="submitted && form.category === null ? 'Required.' : ''"
        />
      </v-col>
      <v-col cols="12" sm="4">
        <v-select
          v-model="form.unitId"
          :items="unitItems"
          label="Unit"
          :loading="loadingRegistries"
          :error-messages="submitted && form.unitId === null ? 'Required.' : ''"
        />
      </v-col>
      <v-col cols="12" sm="4">
        <v-text-field
          v-model.number="form.quantity"
          label="Quantity"
          type="number"
          min="1"
          step="1"
          :error-messages="quantityError"
        />
      </v-col>
      <v-col cols="12" sm="4">
        <v-text-field
          v-model="form.expiryDate"
          label="Expiry Date (optional)"
          type="date"
          :error-messages="expiryError"
        />
      </v-col>
    </v-row>

    <v-btn
      type="submit"
      color="primary"
      :loading="loading"
      block
      class="mt-2"
    >
      Create Batch
    </v-btn>
  </v-form>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useBatches, CATEGORIES } from '@/composables/useBatches'
import { useAdmin } from '@/composables/useAdmin'
import { useToastStore } from '@/stores/toast'

const emit = defineEmits(['created'])

const { createBatch } = useBatches()
const { getProductTypes, getUnits } = useAdmin()
const toast = useToastStore()

const form = ref({
  serial: '', origin: '', productTypeId: null,
  category: null, unitId: null, quantity: 1, expiryDate: '',
})
const loading           = ref(false)
const loadingRegistries = ref(false)
const submitted         = ref(false)
const productTypeItems  = ref([])
const unitItems         = ref([])

const categoryItems = Object.entries(CATEGORIES).map(([value, title]) => ({
  title,
  value: Number(value),
}))

const quantityError = computed(() => {
  if (form.value.quantity < 1)                    return 'Quantity must be at least 1.'
  if (!Number.isInteger(form.value.quantity))      return 'Quantity must be a whole number.'
  return ''
})

const expiryError = computed(() => {
  if (!form.value.expiryDate) return ''
  const ts  = Math.floor(new Date(form.value.expiryDate).getTime() / 1000)
  const now = Math.floor(Date.now() / 1000)
  return ts <= now ? 'Expiry date must be in the future.' : ''
})

const isValid = computed(() =>
  form.value.serial.trim() &&
  form.value.origin.trim() &&
  form.value.productTypeId !== null &&
  form.value.category !== null &&
  form.value.unitId !== null &&
  form.value.quantity >= 1 &&
  Number.isInteger(form.value.quantity) &&
  !expiryError.value
)

onMounted(async () => {
  loadingRegistries.value = true
  const [types, units] = await Promise.all([getProductTypes(), getUnits()])
  productTypeItems.value = types.map((name, index) => ({ title: name, value: index }))
  unitItems.value        = units.map((name, index) => ({ title: name, value: index }))
  loadingRegistries.value = false
})

async function submit() {
  submitted.value = true
  if (!isValid.value) return

  loading.value = true
  try {
    const expiry = form.value.expiryDate
      ? Math.floor(new Date(form.value.expiryDate).getTime() / 1000)
      : 0

    const createdSerial = form.value.serial
    await createBatch(
      createdSerial,
      form.value.productTypeId,
      form.value.category,
      form.value.unitId,
      form.value.quantity,
      form.value.origin,
      expiry,
    )
    toast.show(`Batch ${createdSerial} created.`, 'success')
    form.value = { serial: '', origin: '', productTypeId: null, category: null, unitId: null, quantity: 1, expiryDate: '' }
    submitted.value = false
    // Pass the serial so the dashboard can read the new batch straight from chain
    // (avoids the subgraph's indexing lag for a record that was just created).
    emit('created', createdSerial)
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    loading.value = false
  }
}
</script>
