<template>
  <v-container class="py-8">
    <!-- ── Hero ──────────────────────────────────────────────────────── -->
    <v-row justify="center" class="mb-8">
      <v-col cols="12" md="8" class="text-center">
        <v-icon icon="mdi-link-variant" size="72" color="primary" class="mb-4" />
        <h1 class="text-h3 font-weight-bold mb-3">TrustChain</h1>
        <p class="text-h6 text-medium-emphasis mb-6">
          Immutable supply chain traceability powered by blockchain.
          Track every product batch from production to final distribution.
        </p>

        <div v-if="!wallet.isConnected" class="d-flex justify-center gap-3">
          <WalletConnect />
        </div>

        <div v-else>
          <v-alert
            type="success"
            variant="tonal"
            rounded="lg"
            class="text-left mb-4"
          >
            <template #prepend>
              <RoleBadge :role="roleLabel" />
            </template>
            Connected as {{ wallet.shortAddress }} · Role: <strong>{{ roleLabel }}</strong>
          </v-alert>
          <div class="d-flex justify-center gap-3">
            <v-btn color="primary" size="large" to="/dashboard" prepend-icon="mdi-view-dashboard">
              Go to Dashboard
            </v-btn>
            <v-btn color="secondary" size="large" to="/search" prepend-icon="mdi-magnify">
              Search Batch
            </v-btn>
          </div>
        </div>

        <!-- Route reason messages from router guard -->
        <v-alert v-if="routeReason === 'unregistered'" type="warning" variant="tonal" class="mt-4 text-left">
          Your address is not registered in TrustChain. Contact an admin to get access.
        </v-alert>
      </v-col>
    </v-row>

    <!-- ── Feature Cards ─────────────────────────────────────────────── -->
    <v-row justify="center">
      <v-col
        v-for="feat in features"
        :key="feat.title"
        cols="12"
        sm="6"
        md="4"
      >
        <v-card color="surface-variant" rounded="lg" height="100%">
          <v-card-item>
            <template #prepend>
              <v-icon :icon="feat.icon" :color="feat.color" size="36" />
            </template>
            <v-card-title>{{ feat.title }}</v-card-title>
          </v-card-item>
          <v-card-text class="text-medium-emphasis">
            {{ feat.description }}
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- ── Role Overview ─────────────────────────────────────────────── -->
    <v-row justify="center" class="mt-8">
      <v-col cols="12" md="10">
        <v-card color="surface-variant" rounded="lg">
          <v-card-title class="text-h6 pa-4">System Roles</v-card-title>
          <v-divider />
          <v-list bg-color="transparent" density="compact">
            <v-list-item
              v-for="r in roleOverview"
              :key="r.role"
              :prepend-icon="r.icon"
            >
              <template #prepend>
                <v-icon :icon="r.icon" :color="r.color" class="mr-3" />
              </template>
              <v-list-item-title>
                <v-chip :color="r.color" size="x-small" label class="mr-2">{{ r.role }}</v-chip>
                {{ r.description }}
              </v-list-item-title>
            </v-list-item>
          </v-list>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useWalletStore } from '@/stores/wallet'
import { useUserRole } from '@/composables/useUserRole'
import WalletConnect from '@/components/common/WalletConnect.vue'
import RoleBadge from '@/components/common/RoleBadge.vue'

const wallet     = useWalletStore()
const { roleLabel } = useUserRole()
const route      = useRoute()
const routeReason = computed(() => route.query.reason ?? null)

const features = [
  { icon: 'mdi-shield-lock', color: 'primary',   title: 'Tamper-Proof',     description: 'Every state change is recorded on-chain as an immutable event — no one can alter the history.' },
  { icon: 'mdi-eye',         color: 'secondary', title: 'Full Transparency', description: 'All authorised parties can independently verify where a product has been and who handled it.' },
  { icon: 'mdi-account-group', color: 'orange',  title: 'Role-Based Access', description: '6 defined roles — Producer, Transporter, Warehouse, Distributor, Auditor, Admin — each with strict permissions.' },
  { icon: 'mdi-timeline',    color: 'cyan',      title: 'Event Timeline',    description: 'Complete route history reconstructed from on-chain events: every hop, actor, and location.' },
  { icon: 'mdi-bell-alert',  color: 'red',       title: 'Recall System',     description: 'Auditors can recall batches at any time. Recalled goods are permanently flagged and cannot be redistributed.' },
  { icon: 'mdi-check-decagram', color: 'green',  title: 'Certification',     description: 'Auditors can certify batches, providing an additional on-chain quality assurance signal.' },
]

const roleOverview = [
  { role: 'ADMIN',       color: 'red',    icon: 'mdi-shield-crown',  description: 'Register users, manage product type + unit registries.' },
  { role: 'PRODUCER',    color: 'green',  icon: 'mdi-factory',       description: 'Create product batches.' },
  { role: 'TRANSPORTER', color: 'blue',   icon: 'mdi-truck',         description: 'Ship batches (STORED / PRODUCED → IN_TRANSIT).' },
  { role: 'WAREHOUSE',   color: 'orange', icon: 'mdi-warehouse',     description: 'Receive batches; dispose recalled goods.' },
  { role: 'DISTRIBUTOR', color: 'cyan',   icon: 'mdi-store',         description: 'Final distribution to point of sale.' },
  { role: 'AUDITOR',     color: 'purple', icon: 'mdi-magnify-scan',  description: 'Full read access, recall batches, certify batches.' },
]
</script>
