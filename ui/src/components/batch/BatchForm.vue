<template>
  <v-form ref="formRef" @submit.prevent="submit">
    <v-row>
      <!-- Serial Number -->
      <v-col cols="12" md="6">
        <v-text-field
          v-model="form.serialNumber"
          label="Serial Number"
          placeholder="OLIVE-GR-001"
          prepend-inner-icon="mdi-barcode"
          :rules="[rules.required, rules.bytes32]"
          variant="outlined"
        />
      </v-col>

      <!-- Origin -->
      <v-col cols="12" md="6">
        <v-text-field
          v-model="form.origin"
          label="Origin / Region"
          placeholder="GR-PEL"
          prepend-inner-icon="mdi-map-marker"
          :rules="[rules.required, rules.bytes32]"
          variant="outlined"
        />
      </v-col>

      <!-- Product Type -->
      <v-col cols="12" md="4">
        <v-select
          v-model="form.productTypeId"
          :items="productTypeItems"
          label="Product Type"
          prepend-inner-icon="mdi-tag"
          :rules="[rules.required]"
          variant="outlined"
        />
      </v-col>

      <!-- Category -->
      <v-col cols="12" md="4">
        <v-select
          v-model="form.category"
          :items="categoryItems"
          label="Category"
          prepend-inner-icon="mdi-shape"
          :rules="[rules.required]"
          variant="outlined"
        />
      </v-col>

      <!-- Unit -->
      <v-col cols="12" md="4">
        <v-select
          v-model="form.unitId"
          :items="unitItems"
          label="Unit"
          prepend-inner-icon="mdi-scale"
          :rules="[rules.required]"
          variant="outlined"
        />
      </v-col>

      <!-- Quantity -->
      <v-col cols="12" md="6">
        <v-text-field
          v-model="form.quantity"
          label="Quantity"
          type="number"
          min="1"
          prepend-inner-icon="mdi-numeric"
          :rules="[rules.required, rules.positiveInt]"
          variant="outlined"
        />
      </v-col>

      <!-- Expiry Date (optional) -->
      <v-col cols="12" md="6">
        <v-text-field
          v-model="form.expiryDateStr"
          label="Expiry Date (optional)"
          type="date"
          prepend-inner-icon="mdi-calendar-clock"
          :rules="[rules.futureDate]"
          variant="outlined"
          clearable
        />
      </v-col>
    </v-row>

    <div class="d-flex gap-2 justify-end">
      <v-btn variant="text" @click="reset">Clear</v-btn>
      <v-btn
        type="submit"
        color="primary"
        :loading="loading"
        prepend-icon="mdi-plus-circle"
      >
        Create Batch
      </v-btn>
    </div>
  </v-form>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useBatches, CATEGORY_LABELS } from '@/composables/useBatches'
import { useAdmin } from '@/composables/useAdmin'

const emit = defineEmits(['created'])

const { createBatch, loading, error } = useBatches()
const admin = useAdmin()

const formRef = ref(null)
const productTypes = ref([])
const units = ref([])

onMounted(async () => {
  productTypes.value = await admin.getProductTypes()
  units.value        = await admin.getUnits()
})

const form = ref({
  serialNumber:  '',
  origin:        '',
  productTypeId: null,
  category:      null,
  unitId:        null,
  quantity:      '',
  expiryDateStr: '',
})

const productTypeItems = computed(() =>
  productTypes.value.map((name, idx) => ({ title: name, value: idx }))
)

const unitItems = computed(() =>
  units.value.map((name, idx) => ({ title: name, value: idx }))
)

const categoryItems = Object.entries(CATEGORY_LABELS).map(([num, label]) => ({
  title: label,
  value: Number(num),
}))

const rules = {
  required:    (v) => (v !== null && v !== '' && v !== undefined) || 'Required',
  bytes32:     (v) => v.length <= 31 || 'Max 31 characters (bytes32)',
  positiveInt: (v) => (Number(v) >= 1) || 'Must be at least 1',
  futureDate:  (v) => {
    if (!v) return true
    return new Date(v) > new Date() || 'Expiry date must be in the future'
  },
}

async function submit() {
  const { valid } = await formRef.value.validate()
  if (!valid) return

  const expiryDate = form.value.expiryDateStr
    ? Math.floor(new Date(form.value.expiryDateStr).getTime() / 1000)
    : 0

  const ok = await createBatch({
    serialNumber:  form.value.serialNumber,
    productTypeId: form.value.productTypeId,
    category:      form.value.category,
    unitId:        form.value.unitId,
    quantity:      BigInt(form.value.quantity),
    origin:        form.value.origin,
    expiryDate,
  })

  if (ok) {
    emit('created', form.value.serialNumber)
    reset()
  }
}

function reset() {
  formRef.value?.reset()
}
</script>
