<template>
  <v-container class="py-8">
    <h2 class="mb-6">Dashboard</h2>

    <!-- ── Admin Panel ──────────────────────────────────────────────────── -->
    <template v-if="roleLabel === 'ADMIN'">
      <v-tabs v-model="tab" color="primary" class="mb-4">
        <v-tab value="register">Register User</v-tab>
        <v-tab value="manage">Manage Users</v-tab>
        <v-tab value="registries">Registries</v-tab>
      </v-tabs>

      <v-window v-model="tab">

        <!-- Tab 1: Register a new user -->
        <v-window-item value="register">
          <v-card max-width="480" class="pa-6">
            <v-card-title class="mb-4">Register New User</v-card-title>
            <UserForm @registered="loadUsers" />
          </v-card>
        </v-window-item>

        <!-- Tab 2: All registered users -->
        <v-window-item value="manage">
          <v-data-table
            :headers="userHeaders"
            :items="users"
            :loading="loadingUsers"
            density="comfortable"
          >
            <template #item.role="{ item }">
              <v-chip :color="ROLE_COLORS[ROLES[item.role]]" size="small" variant="tonal">
                {{ ROLES[item.role] }}
              </v-chip>
            </template>
            <template #item.isActive="{ item }">
              <v-chip :color="item.isActive ? 'success' : 'error'" size="small" variant="tonal">
                {{ item.isActive ? 'Active' : 'Inactive' }}
              </v-chip>
            </template>
            <template #item.actions="{ item }">
              <v-btn
                v-if="item.isActive"
                size="small"
                color="error"
                variant="tonal"
                :loading="actionLoading === item.address"
                @click="deactivate(item.address)"
              >
                Deactivate
              </v-btn>
              <v-btn
                v-else
                size="small"
                color="success"
                variant="tonal"
                :loading="actionLoading === item.address"
                @click="activate(item.address)"
              >
                Activate
              </v-btn>
            </template>
          </v-data-table>
        </v-window-item>

        <!-- Tab 3: Product types and units -->
        <v-window-item value="registries">
          <v-row>
            <v-col cols="12" md="6">
              <v-card class="pa-4">
                <v-card-title>Product Types</v-card-title>
                <v-list density="compact">
                  <v-list-item v-for="pt in productTypes" :key="pt" :title="pt" />
                </v-list>
                <v-divider class="my-3" />
                <v-text-field v-model="newProductType" label="New product type" density="compact" hide-details class="mb-2" />
                <v-btn color="primary" size="small" :loading="addingPT" @click="addPT">Add</v-btn>
              </v-card>
            </v-col>
            <v-col cols="12" md="6">
              <v-card class="pa-4">
                <v-card-title>Units</v-card-title>
                <v-list density="compact">
                  <v-list-item v-for="u in units" :key="u" :title="u" />
                </v-list>
                <v-divider class="my-3" />
                <v-text-field v-model="newUnit" label="New unit" density="compact" hide-details class="mb-2" />
                <v-btn color="primary" size="small" :loading="addingUnit" @click="addU">Add</v-btn>
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>

      </v-window>
    </template>

    <!-- Not an admin -->
    <v-alert v-else type="info" variant="tonal">
      Role-specific panels coming soon.
    </v-alert>

  </v-container>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAdmin } from '@/composables/useAdmin'
import { useUserRole, ROLES, ROLE_COLORS } from '@/composables/useUserRole'
import { useBatches } from '@/composables/useBatches'
import { useToastStore } from '@/stores/toast'
import UserForm from '@/components/admin/UserForm.vue'

const { fetchAllUsers, deactivateUser, activateUser,
        getProductTypes, getUnits, addProductType, addUnit } = useAdmin()
const { fetchAllBatches } = useBatches()
const { roleLabel } = useUserRole()
const toast = useToastStore()

const tab          = ref('register')
const users        = ref([])
const loadingUsers = ref(false)
const actionLoading = ref(null)

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

async function loadUsers() {
  loadingUsers.value = true
  try   { users.value = await fetchAllUsers() }
  catch { toast.show('Failed to load users.', 'error') }
  finally { loadingUsers.value = false }
}

async function deactivate(address) {
  actionLoading.value = address
  try {
    await deactivateUser(address)
    toast.show('User deactivated.', 'success')
    await loadUsers()
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    actionLoading.value = null
  }
}

async function activate(address) {
  actionLoading.value = address
  try {
    await activateUser(address)
    toast.show('User activated.', 'success')
    await loadUsers()
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    actionLoading.value = null
  }
}

async function addPT() {
  const name = newProductType.value.trim().toUpperCase()
  if (!name) return
  if (productTypes.value.includes(name)) {
    toast.show(`"${name}" already exists.`, 'warning'); return
  }
  addingPT.value = true
  try {
    await addProductType(name)
    toast.show(`"${name}" added.`, 'success')
    newProductType.value = ''
    productTypes.value = await getProductTypes()
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    addingPT.value = false
  }
}

async function addU() {
  const name = newUnit.value.trim().toUpperCase()
  if (!name) return
  if (units.value.includes(name)) {
    toast.show(`"${name}" already exists.`, 'warning'); return
  }
  addingUnit.value = true
  try {
    await addUnit(name)
    toast.show(`"${name}" added.`, 'success')
    newUnit.value = ''
    units.value = await getUnits()
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    addingUnit.value = false
  }
}

onMounted(async () => {
  await loadUsers()
  productTypes.value = await getProductTypes()
  units.value        = await getUnits()
  const batches = await fetchAllBatches()
  console.log('fetchAllBatches() →', batches)
})
</script>
