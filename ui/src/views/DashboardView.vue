<template>
  <v-container class="py-8">
    <v-row class="mb-4" align="center">
      <v-col>
        <h2 class="text-h5 font-weight-bold">
          <v-icon icon="mdi-view-dashboard" class="mr-2" />
          Dashboard
        </h2>
        <div class="text-medium-emphasis text-body-2">
          Logged in as {{ wallet.shortAddress }} ·
          <RoleBadge v-if="roleLabel" :role="roleLabel" />
        </div>
      </v-col>
      <v-col cols="auto">
        <v-btn
          variant="tonal"
          color="secondary"
          prepend-icon="mdi-refresh"
          :loading="loading"
          @click="refresh"
        >
          Refresh
        </v-btn>
      </v-col>
    </v-row>

    <v-expansion-panels v-model="openPanels" multiple variant="accordion">

      <!-- ══ ADMIN ══════════════════════════════════════════════════════ -->
      <v-expansion-panel v-if="isAdmin" value="admin">
        <v-expansion-panel-title>
          <v-icon icon="mdi-shield-crown" color="red" class="mr-2" />
          Admin — User Management
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <v-tabs v-model="adminTab" color="primary" class="mb-4">
            <v-tab value="register">Register User</v-tab>
            <v-tab value="manage">Manage Users</v-tab>
            <v-tab value="registries">Registries</v-tab>
          </v-tabs>

          <v-window v-model="adminTab">
            <v-window-item value="register">
              <UserForm @registered="onUserRegistered" />
            </v-window-item>

            <v-window-item value="manage">
              <v-text-field
                v-model="userSearch"
                label="Search users"
                prepend-inner-icon="mdi-magnify"
                variant="outlined"
                density="compact"
                clearable
                class="mb-3"
              />

              <v-skeleton-loader v-if="usersLoading" type="table-tbody" />

              <v-data-table
                v-else
                :headers="userHeaders"
                :items="allUsers"
                :search="userSearch"
                density="compact"
                hover
                rounded="lg"
              >
                <template #item.role="{ item }">
                  <v-chip
                    :color="ROLE_COLORS[ROLES[item.role]] ?? 'grey'"
                    size="x-small"
                    variant="tonal"
                    label
                  >
                    {{ ROLES[item.role] }}
                  </v-chip>
                </template>

                <template #item.ethAddress="{ item }">
                  <span class="font-mono text-caption">
                    {{ item.ethAddress.slice(0, 10) }}…{{ item.ethAddress.slice(-4) }}
                  </span>
                </template>

                <template #item.isActive="{ item }">
                  <v-chip :color="item.isActive ? 'success' : 'error'" size="x-small" variant="tonal">
                    {{ item.isActive ? 'Active' : 'Inactive' }}
                  </v-chip>
                </template>

                <template #item.actions="{ item }">
                  <v-btn
                    :color="item.isActive ? 'error' : 'success'"
                    size="x-small"
                    variant="tonal"
                    :loading="manageBusy === item.ethAddress"
                    @click.stop="handleToggle(item)"
                  >
                    {{ item.isActive ? 'Deactivate' : 'Activate' }}
                  </v-btn>
                </template>

                <template #no-data>
                  <span class="text-medium-emphasis text-caption">No users registered yet.</span>
                </template>
              </v-data-table>
            </v-window-item>

            <v-window-item value="registries">
              <v-row>
                <!-- Product Types -->
                <v-col cols="12" md="6">
                  <p class="text-subtitle-2 mb-2">Product Types</p>
                  <v-chip
                    v-for="(pt, idx) in productTypes"
                    :key="idx"
                    class="mr-1 mb-1"
                    color="secondary"
                    variant="tonal"
                    size="small"
                    label
                  >
                    #{{ idx }} {{ pt }}
                  </v-chip>
                  <v-text-field
                    v-model="newProductType"
                    label="Add Product Type"
                    density="compact"
                    variant="outlined"
                    class="mt-3"
                    @keyup.enter="addProductType"
                  >
                    <template #append-inner>
                      <v-btn icon="mdi-plus" size="small" variant="text" @click="addProductType" />
                    </template>
                  </v-text-field>
                </v-col>

                <!-- Units -->
                <v-col cols="12" md="6">
                  <p class="text-subtitle-2 mb-2">Units</p>
                  <v-chip
                    v-for="(u, idx) in units"
                    :key="idx"
                    class="mr-1 mb-1"
                    color="orange"
                    variant="tonal"
                    size="small"
                    label
                  >
                    #{{ idx }} {{ u }}
                  </v-chip>
                  <v-text-field
                    v-model="newUnit"
                    label="Add Unit"
                    density="compact"
                    variant="outlined"
                    class="mt-3"
                    @keyup.enter="addUnit"
                  >
                    <template #append-inner>
                      <v-btn icon="mdi-plus" size="small" variant="text" @click="addUnit" />
                    </template>
                  </v-text-field>
                </v-col>
              </v-row>
            </v-window-item>
          </v-window>
        </v-expansion-panel-text>
      </v-expansion-panel>

      <!-- ══ PRODUCER ══════════════════════════════════════════════════ -->
      <v-expansion-panel v-if="isProducer" value="producer">
        <v-expansion-panel-title>
          <v-icon icon="mdi-factory" color="green" class="mr-2" />
          Producer — Create Batch
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <BatchForm @created="onBatchCreated" />

          <v-divider class="my-4" />
          <p class="text-subtitle-2 mb-3">My Batches</p>

          <v-skeleton-loader v-if="loading" type="card@3" />
          <v-row v-else>
            <v-col
              v-for="b in myBatches"
              :key="b.serialRaw"
              cols="12" md="6" lg="4"
            >
              <BatchCard
                :batch="b"
                :product-types="productTypes"
                :units="units"
                :link-to="`/batch/${b.serialNumber}`"
              />
            </v-col>
            <v-col v-if="!myBatches.length" cols="12">
              <v-alert type="info" variant="tonal">No batches created yet.</v-alert>
            </v-col>
          </v-row>
        </v-expansion-panel-text>
      </v-expansion-panel>

      <!-- ══ WAREHOUSE ══════════════════════════════════════════════════ -->
      <v-expansion-panel v-if="isWarehouse" value="warehouse">
        <v-expansion-panel-title>
          <v-icon icon="mdi-warehouse" color="orange" class="mr-2" />
          Warehouse — Receive / Dispose
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <v-tabs v-model="warehouseTab" color="primary" class="mb-4">
            <v-tab value="my-batches">My Batches</v-tab>
            <v-tab value="receive">Receive</v-tab>
            <v-tab value="dispose">Dispose</v-tab>
          </v-tabs>

          <v-window v-model="warehouseTab">
            <v-window-item value="my-batches">
              <v-skeleton-loader v-if="heldBatchesLoading" type="card@3" />
              <v-row v-else>
                <v-col
                  v-for="b in heldBatches"
                  :key="b.serialRaw"
                  cols="12" md="6" lg="4"
                >
                  <BatchCard
                    :batch="b"
                    :product-types="productTypes"
                    :units="units"
                    :link-to="`/batch/${b.serialNumber}`"
                  />
                </v-col>
                <v-col v-if="!heldBatches.length" cols="12">
                  <v-alert type="info" variant="tonal">No batches currently in your possession.</v-alert>
                </v-col>
              </v-row>
            </v-window-item>

            <v-window-item value="receive">
              <TransitionForm
                action="receiveBatch"
                label="Receive Batch"
                icon="mdi-package-down"
                color="blue"
                @done="onRoleAction"
              />
            </v-window-item>

            <v-window-item value="dispose">
              <TransitionForm
                action="disposeBatch"
                label="Dispose Recalled Batch"
                icon="mdi-delete"
                color="deep-purple"
                @done="onRoleAction"
              />
            </v-window-item>
          </v-window>
        </v-expansion-panel-text>
      </v-expansion-panel>

      <!-- ══ TRANSPORTER ════════════════════════════════════════════════ -->
      <v-expansion-panel v-if="isTransporter" value="transporter">
        <v-expansion-panel-title>
          <v-icon icon="mdi-truck" color="blue" class="mr-2" />
          Transporter — Ship Batch
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <v-tabs v-model="transporterTab" color="primary" class="mb-4">
            <v-tab value="my-batches">My Batches</v-tab>
            <v-tab value="ship">Ship</v-tab>
          </v-tabs>

          <v-window v-model="transporterTab">
            <v-window-item value="my-batches">
              <v-skeleton-loader v-if="heldBatchesLoading" type="card@3" />
              <v-row v-else>
                <v-col
                  v-for="b in heldBatches"
                  :key="b.serialRaw"
                  cols="12" md="6" lg="4"
                >
                  <BatchCard
                    :batch="b"
                    :product-types="productTypes"
                    :units="units"
                    :link-to="`/batch/${b.serialNumber}`"
                  />
                </v-col>
                <v-col v-if="!heldBatches.length" cols="12">
                  <v-alert type="info" variant="tonal">No batches currently in your possession.</v-alert>
                </v-col>
              </v-row>
            </v-window-item>

            <v-window-item value="ship">
              <TransitionForm
                action="shipBatch"
                label="Ship Batch"
                icon="mdi-truck-fast"
                color="blue"
                @done="onRoleAction"
              />
            </v-window-item>
          </v-window>
        </v-expansion-panel-text>
      </v-expansion-panel>

      <!-- ══ DISTRIBUTOR ════════════════════════════════════════════════ -->
      <v-expansion-panel v-if="isDistributor" value="distributor">
        <v-expansion-panel-title>
          <v-icon icon="mdi-store" color="cyan" class="mr-2" />
          Distributor — Distribute Batch
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <v-tabs v-model="distributorTab" color="primary" class="mb-4">
            <v-tab value="my-batches">My Batches</v-tab>
            <v-tab value="distribute">Distribute</v-tab>
          </v-tabs>

          <v-window v-model="distributorTab">
            <v-window-item value="my-batches">
              <v-skeleton-loader v-if="heldBatchesLoading" type="card@3" />
              <v-row v-else>
                <v-col
                  v-for="b in heldBatches"
                  :key="b.serialRaw"
                  cols="12" md="6" lg="4"
                >
                  <BatchCard
                    :batch="b"
                    :product-types="productTypes"
                    :units="units"
                    :link-to="`/batch/${b.serialNumber}`"
                  />
                </v-col>
                <v-col v-if="!heldBatches.length" cols="12">
                  <v-alert type="info" variant="tonal">No batches currently in your possession.</v-alert>
                </v-col>
              </v-row>
            </v-window-item>

            <v-window-item value="distribute">
              <TransitionForm
                action="distributeBatch"
                label="Distribute Batch"
                icon="mdi-store-check"
                color="cyan"
                @done="onRoleAction"
              />
            </v-window-item>
          </v-window>
        </v-expansion-panel-text>
      </v-expansion-panel>

      <!-- ══ AUDITOR ════════════════════════════════════════════════════ -->
      <v-expansion-panel v-if="isAuditor" value="auditor">
        <v-expansion-panel-title>
          <v-icon icon="mdi-magnify-scan" color="purple" class="mr-2" />
          Auditor — Oversight &amp; Actions
        </v-expansion-panel-title>
        <v-expansion-panel-text>
          <v-tabs v-model="auditorTab" color="primary" class="mb-4">
            <v-tab value="all-batches">All Batches</v-tab>
            <v-tab value="recall">Recall</v-tab>
            <v-tab value="certify">Certify</v-tab>
          </v-tabs>

          <v-window v-model="auditorTab">

            <!-- ── All Batches ─────────────────────────────────────── -->
            <v-window-item value="all-batches">
              <v-text-field
                v-model="batchSearch"
                label="Search batches"
                prepend-inner-icon="mdi-magnify"
                variant="outlined"
                density="compact"
                clearable
                class="mb-3"
              />

              <v-skeleton-loader v-if="allBatchesLoading" type="table-tbody" />

              <v-data-table
                v-else
                :headers="batchHeaders"
                :items="allBatches"
                :search="batchSearch"
                density="compact"
                hover
                rounded="lg"
                :items-per-page="15"
              >
                <template #item.serialNumber="{ item }">
                  <router-link
                    :to="`/batch/${item.serialNumber}`"
                    class="text-caption font-mono text-primary"
                  >
                    {{ item.serialNumber }}
                  </router-link>
                </template>

                <template #item.status="{ item }">
                  <v-chip
                    :color="STATUS_COLORS[item.status] ?? 'grey'"
                    size="x-small"
                    variant="tonal"
                    label
                  >
                    {{ item.status }}
                  </v-chip>
                </template>

                <template #item.productTypeId="{ item }">
                  {{ productTypes[item.productTypeId] ?? `#${item.productTypeId}` }}
                </template>

                <template #item.currentHolder="{ item }">
                  <AddressChip :address="item.currentHolder" />
                </template>

                <template #item.certified="{ item }">
                  <v-icon
                    v-if="item.certified"
                    icon="mdi-check-decagram"
                    color="success"
                    size="18"
                  />
                  <v-icon v-else icon="mdi-minus" color="secondary" size="18" />
                </template>

                <template #item.recalled="{ item }">
                  <v-icon
                    v-if="item.recalled"
                    icon="mdi-alert"
                    color="error"
                    size="18"
                  />
                  <v-icon v-else icon="mdi-minus" color="secondary" size="18" />
                </template>

                <template #no-data>
                  <span class="text-medium-emphasis text-caption">No batches found.</span>
                </template>
              </v-data-table>
            </v-window-item>

            <!-- ── Recall ──────────────────────────────────────────── -->
            <v-window-item value="recall">
              <TransitionForm
                action="recallBatch"
                label="Recall Batch"
                icon="mdi-alert"
                color="red"
                @done="onAuditorAction"
              />
            </v-window-item>

            <!-- ── Certify ─────────────────────────────────────────── -->
            <v-window-item value="certify">
              <v-card-text>
                <p class="text-subtitle-2 mb-3">Certify Batch</p>
                <v-text-field
                  v-model="certifySerial"
                  label="Serial Number"
                  variant="outlined"
                  density="compact"
                  prepend-inner-icon="mdi-barcode"
                  class="mb-2"
                />
                <v-btn
                  color="success"
                  :loading="certifyLoading"
                  prepend-icon="mdi-check-decagram"
                  @click="doCertify"
                >
                  Certify
                </v-btn>
              </v-card-text>
            </v-window-item>

          </v-window>
        </v-expansion-panel-text>
      </v-expansion-panel>

    </v-expansion-panels>
  </v-container>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useWalletStore } from '@/stores/wallet'
import { useUserRole, ROLES, ROLE_COLORS } from '@/composables/useUserRole'
import { useBatches, STATUS_COLORS } from '@/composables/useBatches'
import { useAdmin } from '@/composables/useAdmin'
import RoleBadge from '@/components/common/RoleBadge.vue'
import AddressChip from '@/components/common/AddressChip.vue'
import UserForm from '@/components/admin/UserForm.vue'
import BatchForm from '@/components/batch/BatchForm.vue'
import BatchCard from '@/components/batch/BatchCard.vue'
import TransitionForm from '@/components/batch/TransitionForm.vue'

// ── State ─────────────────────────────────────────────────────────────────
const wallet   = useWalletStore()
const { roleLabel } = useUserRole()
const { fetchMyBatches, fetchAllBatches, fetchHeldBatches, certifyBatch, loading } = useBatches()
const admin = useAdmin()

const allUsers       = ref([])
const usersLoading   = ref(false)
const manageBusy     = ref(null)   // holds address being toggled
const userSearch     = ref('')

const openPanels     = ref([])
const myBatches      = ref([])
const productTypes   = ref([])
const units          = ref([])
const newProductType = ref('')
const newUnit        = ref('')
const adminTab       = ref('register')
const auditorTab     = ref('all-batches')
const warehouseTab   = ref('my-batches')
const transporterTab = ref('my-batches')
const distributorTab = ref('my-batches')
const certifySerial  = ref('')
const certifyLoading = ref(false)

const heldBatches        = ref([])
const heldBatchesLoading = ref(false)

const allBatches        = ref([])
const allBatchesLoading = ref(false)
const batchSearch       = ref('')

const batchHeaders = [
  { title: 'Serial',       key: 'serialNumber',  sortable: true },
  { title: 'Status',       key: 'status',        sortable: true },
  { title: 'Product',      key: 'productTypeId', sortable: true },
  { title: 'Origin',       key: 'origin',        sortable: true },
  { title: 'Holder',       key: 'currentHolder', sortable: false },
  { title: 'Certified',    key: 'certified',     sortable: true },
  { title: 'Recalled',     key: 'recalled',      sortable: true },
]

// ── User table config ──────────────────────────────────────────────────────
const userHeaders = [
  { title: 'Name',    key: 'name',       sortable: true },
  { title: 'Role',    key: 'role',       sortable: true },
  { title: 'Address', key: 'ethAddress', sortable: false },
  { title: 'Status',  key: 'isActive',   sortable: true },
  { title: '',        key: 'actions',    sortable: false, align: 'end' },
]

// ── Admin actions ──────────────────────────────────────────────────────────
async function loadAllUsers() {
  usersLoading.value = true
  allUsers.value = await admin.fetchAllUsers()
  usersLoading.value = false
}

async function handleToggle(user) {
  manageBusy.value = user.ethAddress
  if (user.isActive) {
    await admin.deactivateUser(user.ethAddress)
  } else {
    await admin.activateUser(user.ethAddress)
  }
  await loadAllUsers()
  manageBusy.value = null
}

// ── Role helpers ───────────────────────────────────────────────────────────
const isAdmin       = computed(() => roleLabel.value === 'ADMIN')
const isProducer    = computed(() => roleLabel.value === 'PRODUCER')
const isWarehouse   = computed(() => roleLabel.value === 'WAREHOUSE')
const isTransporter = computed(() => roleLabel.value === 'TRANSPORTER')
const isDistributor = computed(() => roleLabel.value === 'DISTRIBUTOR')
const isAuditor     = computed(() => roleLabel.value === 'AUDITOR')

watch(isAdmin,       (val) => { if (val) loadAllUsers() }, { immediate: true })
watch(isProducer,    (val) => { if (val) fetchMyBatches().then(b => { myBatches.value = b }) }, { immediate: true })
watch(isAuditor,     (val) => { if (val) loadAllBatchesForAuditor() }, { immediate: true })
watch(isWarehouse,   (val) => { if (val) loadHeldBatches() }, { immediate: true })
watch(isTransporter, (val) => { if (val) loadHeldBatches() }, { immediate: true })
watch(isDistributor, (val) => { if (val) loadHeldBatches() }, { immediate: true })

const sectionMap = {
  ADMIN: 'admin', PRODUCER: 'producer', WAREHOUSE: 'warehouse',
  TRANSPORTER: 'transporter', DISTRIBUTOR: 'distributor', AUDITOR: 'auditor',
}
watch(roleLabel, (val) => {
  if (val && sectionMap[val]) openPanels.value = [sectionMap[val]]
}, { immediate: true })

onMounted(async () => {
  ;[productTypes.value, units.value] = await Promise.all([
    admin.getProductTypes(),
    admin.getUnits(),
  ])
})

// ── Refresh ────────────────────────────────────────────────────────────────
async function refresh() {
  ;[productTypes.value, units.value] = await Promise.all([
    admin.getProductTypes(),
    admin.getUnits(),
  ])
  if (isProducer.value)    myBatches.value = await fetchMyBatches()
  if (isAdmin.value)       await loadAllUsers()
  if (isAuditor.value)     await loadAllBatchesForAuditor()
  if (isWarehouse.value || isTransporter.value || isDistributor.value) await loadHeldBatches()
}

// ── Events ─────────────────────────────────────────────────────────────────
async function onBatchCreated() {
  if (isProducer.value) myBatches.value = await fetchMyBatches()
}

function onUserRegistered() {
  loadAllUsers()
}

// ── Registries ─────────────────────────────────────────────────────────────
async function addProductType() {
  if (!newProductType.value) return
  await admin.addProductType(newProductType.value)
  newProductType.value = ''
  productTypes.value   = await admin.getProductTypes()
}

async function addUnit() {
  if (!newUnit.value) return
  await admin.addUnit(newUnit.value)
  newUnit.value = ''
  units.value   = await admin.getUnits()
}

// ── Auditor ────────────────────────────────────────────────────────────────
async function loadHeldBatches() {
  heldBatchesLoading.value = true
  heldBatches.value = await fetchHeldBatches()
  heldBatchesLoading.value = false
}

async function onRoleAction() {
  await refresh()
}

async function loadAllBatchesForAuditor() {
  allBatchesLoading.value = true
  allBatches.value = await fetchAllBatches()
  allBatchesLoading.value = false
}

async function onAuditorAction() {
  await refresh()
}

// ── Certify ────────────────────────────────────────────────────────────────
async function doCertify() {
  if (!certifySerial.value) return
  certifyLoading.value = true
  const ok = await certifyBatch(certifySerial.value)
  certifyLoading.value = false
  if (ok) certifySerial.value = ''
}
</script>
