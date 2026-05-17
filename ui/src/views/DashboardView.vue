<template>
  <v-container class="py-8">
    <h2 class="mb-6">Dashboard</h2>

    <!-- ── ADMIN ──────────────────────────────────────────────────────── -->
    <template v-if="roleLabel === 'ADMIN'">
      <v-tabs v-model="tab" color="primary" class="mb-4">
        <v-tab value="register">Register User</v-tab>
        <v-tab value="manage">Manage Users</v-tab>
        <v-tab value="registries">Registries</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="register">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Register New User</v-card-title>
            <UserForm @registered="loadUsers" />
          </v-card>
        </v-window-item>
        <v-window-item value="manage">
          <v-data-table :headers="userHeaders" :items="users" :loading="loadingUsers" density="comfortable">
            <template #item.role="{ item }">
              <v-chip :color="ROLE_COLORS[ROLES[item.role]]" size="small" variant="tonal">{{ ROLES[item.role] }}</v-chip>
            </template>
            <template #item.isActive="{ item }">
              <v-chip :color="item.isActive ? 'success' : 'error'" size="small" variant="tonal">{{ item.isActive ? 'Active' : 'Inactive' }}</v-chip>
            </template>
            <template #item.actions="{ item }">
              <v-btn v-if="item.isActive" size="small" color="error" variant="tonal" :loading="actionLoading === item.address" @click="deactivate(item.address)">Deactivate</v-btn>
              <v-btn v-else size="small" color="success" variant="tonal" :loading="actionLoading === item.address" @click="activate(item.address)">Activate</v-btn>
            </template>
          </v-data-table>
        </v-window-item>
        <v-window-item value="registries">
          <v-row>
            <v-col cols="12" md="6">
              <v-card class="pa-4">
                <v-card-title>Product Types</v-card-title>
                <v-list density="compact"><v-list-item v-for="pt in productTypes" :key="pt" :title="pt" /></v-list>
                <v-divider class="my-3" />
                <v-text-field v-model="newProductType" label="New product type" density="compact" hide-details class="mb-2" />
                <v-btn color="primary" size="small" :loading="addingPT" @click="addPT">Add</v-btn>
              </v-card>
            </v-col>
            <v-col cols="12" md="6">
              <v-card class="pa-4">
                <v-card-title>Units</v-card-title>
                <v-list density="compact"><v-list-item v-for="u in units" :key="u" :title="u" /></v-list>
                <v-divider class="my-3" />
                <v-text-field v-model="newUnit" label="New unit" density="compact" hide-details class="mb-2" />
                <v-btn color="primary" size="small" :loading="addingUnit" @click="addU">Add</v-btn>
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>
      </v-window>
    </template>

    <!-- ── PRODUCER ───────────────────────────────────────────────────── -->
    <template v-else-if="roleLabel === 'PRODUCER'">
      <v-tabs v-model="tab" color="primary" class="mb-4">
        <v-tab value="create">Create Batch</v-tab>
        <v-tab value="mybatches">My Batches</v-tab>
        <v-tab value="handoff">Hand Off</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="create">
          <v-card max-width="600" class="pa-6">
            <v-card-title class="mb-4">Create New Batch</v-card-title>
            <BatchForm @created="loadMyBatches" />
          </v-card>
        </v-window-item>
        <v-window-item value="mybatches">
          <BatchGrid :batches="myBatches" :loading="loadingBatches" />
        </v-window-item>
        <v-window-item value="handoff">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Hand Off Custody</v-card-title>
            <CustodyForm @done="loadMyBatches" />
          </v-card>
        </v-window-item>
      </v-window>
    </template>

    <!-- ── WAREHOUSE ──────────────────────────────────────────────────── -->
    <template v-else-if="roleLabel === 'WAREHOUSE'">
      <v-tabs v-model="tab" color="primary" class="mb-4">
        <v-tab value="held">My Batches</v-tab>
        <v-tab value="receive">Receive</v-tab>
        <v-tab value="dispose">Dispose</v-tab>
        <v-tab value="handoff">Hand Off</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="held"><BatchGrid :batches="heldBatches" :loading="loadingBatches" /></v-window-item>
        <v-window-item value="receive">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Receive Batch</v-card-title>
            <TransitionForm label="Receive Batch" :fn="receiveBatch" @done="loadHeldBatches" />
          </v-card>
        </v-window-item>
        <v-window-item value="dispose">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Dispose Batch</v-card-title>
            <TransitionForm label="Dispose Batch" :fn="disposeBatch" @done="loadHeldBatches" />
          </v-card>
        </v-window-item>
        <v-window-item value="handoff">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Hand Off Custody</v-card-title>
            <CustodyForm @done="loadHeldBatches" />
          </v-card>
        </v-window-item>
      </v-window>
    </template>

    <!-- ── TRANSPORTER ────────────────────────────────────────────────── -->
    <template v-else-if="roleLabel === 'TRANSPORTER'">
      <v-tabs v-model="tab" color="primary" class="mb-4">
        <v-tab value="held">My Batches</v-tab>
        <v-tab value="ship">Ship</v-tab>
        <v-tab value="handoff">Hand Off</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="held"><BatchGrid :batches="heldBatches" :loading="loadingBatches" /></v-window-item>
        <v-window-item value="ship">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Ship Batch</v-card-title>
            <TransitionForm label="Ship Batch" :fn="shipBatch" @done="loadHeldBatches" />
          </v-card>
        </v-window-item>
        <v-window-item value="handoff">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Hand Off Custody</v-card-title>
            <CustodyForm @done="loadHeldBatches" />
          </v-card>
        </v-window-item>
      </v-window>
    </template>

    <!-- ── DISTRIBUTOR ────────────────────────────────────────────────── -->
    <template v-else-if="roleLabel === 'DISTRIBUTOR'">
      <v-tabs v-model="tab" color="primary" class="mb-4">
        <v-tab value="held">My Batches</v-tab>
        <v-tab value="distribute">Distribute</v-tab>
        <v-tab value="handoff">Hand Off</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="held"><BatchGrid :batches="heldBatches" :loading="loadingBatches" /></v-window-item>
        <v-window-item value="distribute">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Distribute Batch</v-card-title>
            <TransitionForm label="Distribute Batch" :fn="distributeBatch" @done="loadHeldBatches" />
          </v-card>
        </v-window-item>
        <v-window-item value="handoff">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Hand Off Custody</v-card-title>
            <CustodyForm @done="loadHeldBatches" />
          </v-card>
        </v-window-item>
      </v-window>
    </template>

    <!-- ── AUDITOR ────────────────────────────────────────────────────── -->
    <template v-else-if="roleLabel === 'AUDITOR'">
      <v-tabs v-model="tab" color="primary" class="mb-4">
        <v-tab value="all">All Batches</v-tab>
        <v-tab value="recall">Recall</v-tab>
        <v-tab value="certify">Certify</v-tab>
        <v-tab value="handoff">Hand Off</v-tab>
      </v-tabs>
      <v-window v-model="tab">
        <v-window-item value="all"><BatchGrid :batches="allBatches" :loading="loadingBatches" /></v-window-item>
        <v-window-item value="recall">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Recall Batch</v-card-title>
            <TransitionForm label="Recall Batch" :fn="recallBatch" @done="loadAllBatches" />
          </v-card>
        </v-window-item>
        <v-window-item value="certify">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Certify Batch</v-card-title>
            <TransitionForm label="Certify Batch" :fn="certifyWrapper" :has-location="false" @done="loadAllBatches" />
          </v-card>
        </v-window-item>
        <v-window-item value="handoff">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Hand Off Custody</v-card-title>
            <CustodyForm @done="loadAllBatches" />
          </v-card>
        </v-window-item>
      </v-window>
    </template>

    <!-- Still loading role -->
    <v-progress-circular v-else-if="isLoading" indeterminate color="primary" />

    <!-- Connected but not registered -->
    <v-alert
      v-else
      type="warning"
      variant="tonal"
      icon="mdi-account-off"
      max-width="480"
    >
      This address is not registered in TrustChain. Ask an admin to register you.
    </v-alert>

  </v-container>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useAdmin } from '@/composables/useAdmin'
import { useUserRole, ROLES, ROLE_COLORS } from '@/composables/useUserRole'
import { useBatches } from '@/composables/useBatches'
import { useToastStore } from '@/stores/toast'
import UserForm       from '@/components/admin/UserForm.vue'
import BatchForm      from '@/components/batch/BatchForm.vue'
import BatchGrid      from '@/components/batch/BatchGrid.vue'
import CustodyForm    from '@/components/batch/CustodyForm.vue'
import TransitionForm from '@/components/batch/TransitionForm.vue'

// ── Composables ───────────────────────────────────────────────────────────
const {
  fetchAllUsers, deactivateUser, activateUser,
  getProductTypes, getUnits, addProductType, addUnit,
} = useAdmin()
const {
  fetchMyBatches, fetchHeldBatches, fetchAllBatches,
  receiveBatch, shipBatch, distributeBatch,
  recallBatch, disposeBatch, certifyBatch,
} = useBatches()
const { roleLabel, isLoading } = useUserRole()
const toast = useToastStore()

// ── Shared state ──────────────────────────────────────────────────────────
const tab           = ref(null)
const loadingBatches = ref(false)
const myBatches     = ref([])
const heldBatches   = ref([])
const allBatches    = ref([])

// ── Admin state ───────────────────────────────────────────────────────────
const users          = ref([])
const loadingUsers   = ref(false)
const actionLoading  = ref(null)
const productTypes   = ref([])
const units          = ref([])
const newProductType = ref('')
const newUnit        = ref('')
const addingPT       = ref(false)
const addingUnit     = ref(false)

const userHeaders = [
  { title: 'Name',    key: 'name' },
  { title: 'Address', key: 'address' },
  { title: 'Role',    key: 'role',     sortable: false },
  { title: 'Status',  key: 'isActive', sortable: false },
  { title: 'Actions', key: 'actions',  sortable: false },
]

// ── Auditor: certify has no location parameter ────────────────────────────
const certifyWrapper = (serial) => certifyBatch(serial)

// ── Data loaders ──────────────────────────────────────────────────────────
async function loadUsers() {
  loadingUsers.value = true
  try   { users.value = await fetchAllUsers() }
  catch { toast.show('Failed to load users.', 'error') }
  finally { loadingUsers.value = false }
}

async function loadMyBatches() {
  loadingBatches.value = true
  try   { myBatches.value = await fetchMyBatches() }
  catch { toast.show('Failed to load batches.', 'error') }
  finally { loadingBatches.value = false }
}

async function loadHeldBatches() {
  loadingBatches.value = true
  try   { heldBatches.value = await fetchHeldBatches() }
  catch { toast.show('Failed to load batches.', 'error') }
  finally { loadingBatches.value = false }
}

async function loadAllBatches() {
  loadingBatches.value = true
  try   { allBatches.value = await fetchAllBatches() }
  catch { toast.show('Failed to load batches.', 'error') }
  finally { loadingBatches.value = false }
}

// ── Load data when role is known ──────────────────────────────────────────
watch(roleLabel, async (role) => {
  if (!role) return
  tab.value = null
  if (role === 'ADMIN') {
    await loadUsers()
    productTypes.value = await getProductTypes()
    units.value        = await getUnits()
  } else if (role === 'PRODUCER')   { await loadMyBatches() }
  else if (role === 'AUDITOR')       { await loadAllBatches() }
  else                               { await loadHeldBatches() }
}, { immediate: true })

// ── Admin actions ─────────────────────────────────────────────────────────
async function deactivate(address) {
  actionLoading.value = address
  try { await deactivateUser(address); toast.show('User deactivated.', 'success'); await loadUsers() }
  catch (err) { toast.show(err.message, 'error') }
  finally { actionLoading.value = null }
}

async function activate(address) {
  actionLoading.value = address
  try { await activateUser(address); toast.show('User activated.', 'success'); await loadUsers() }
  catch (err) { toast.show(err.message, 'error') }
  finally { actionLoading.value = null }
}

async function addPT() {
  const name = newProductType.value.trim().toUpperCase()
  if (!name) return
  if (productTypes.value.includes(name)) { toast.show(`"${name}" already exists.`, 'warning'); return }
  addingPT.value = true
  try { await addProductType(name); toast.show(`"${name}" added.`, 'success'); newProductType.value = ''; productTypes.value = await getProductTypes() }
  catch (err) { toast.show(err.message, 'error') }
  finally { addingPT.value = false }
}

async function addU() {
  const name = newUnit.value.trim().toUpperCase()
  if (!name) return
  if (units.value.includes(name)) { toast.show(`"${name}" already exists.`, 'warning'); return }
  addingUnit.value = true
  try { await addUnit(name); toast.show(`"${name}" added.`, 'success'); newUnit.value = ''; units.value = await getUnits() }
  catch (err) { toast.show(err.message, 'error') }
  finally { addingUnit.value = false }
}
</script>
