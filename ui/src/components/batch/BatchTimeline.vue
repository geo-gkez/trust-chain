<template>
  <v-timeline side="end" density="compact">

    <v-timeline-item
      v-for="(entry, i) in entries"
      :key="i"
      :dot-color="dotColor(entry)"
      size="small"
    >
      <!-- Created -->
      <template v-if="entry.type === 'created'">
        <div class="text-body-2 font-weight-bold">Batch Created</div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Producer: {{ short(entry.producer) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.producer)" />
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Block {{ entry.block }}
          <v-btn
            v-if="entry.tx"
            :href="txUrl(entry.tx)"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View transaction on Etherscan"
            title="View on Etherscan"
            icon="mdi-open-in-new"
            size="x-small"
            variant="plain"
            density="compact"
          />
        </div>
      </template>

      <!-- Status transition -->
      <template v-else-if="entry.type === 'transitioned'">
        <div class="text-body-2 font-weight-bold d-flex align-center ga-1">
          <v-chip :color="statusColor(entry.from)" size="x-small" variant="tonal">{{ entry.from }}</v-chip>
          <v-icon size="x-small">mdi-arrow-right</v-icon>
          <v-chip :color="statusColor(entry.to)" size="x-small" variant="tonal">{{ entry.to }}</v-chip>
        </div>
        <div v-if="entry.location" class="text-caption text-medium-emphasis">
          Location: {{ entry.location }}
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Actor: {{ short(entry.actor) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.actor)" />
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Block {{ entry.block }}
          <v-btn
            v-if="entry.tx"
            :href="txUrl(entry.tx)"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View transaction on Etherscan"
            title="View on Etherscan"
            icon="mdi-open-in-new"
            size="x-small"
            variant="plain"
            density="compact"
          />
        </div>
      </template>

      <!-- Custody proposed (step 1 of handoff) -->
      <template v-else-if="entry.type === 'proposed'">
        <div class="text-body-2 font-weight-bold">Custody Proposed</div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          {{ short(entry.from) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.from)" />
          offered to {{ short(entry.to) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.to)" />
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Block {{ entry.block }}
          <v-btn
            v-if="entry.tx"
            :href="txUrl(entry.tx)"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View transaction on Etherscan"
            title="View on Etherscan"
            icon="mdi-open-in-new"
            size="x-small"
            variant="plain"
            density="compact"
          />
        </div>
      </template>

      <!-- Custody offer cancelled (retracted before acceptance) -->
      <template v-else-if="entry.type === 'cancelled'">
        <div class="text-body-2 font-weight-bold">Custody Offer Cancelled</div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          {{ short(entry.from) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.from)" />
          retracted offer to {{ short(entry.to) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.to)" />
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Block {{ entry.block }}
          <v-btn
            v-if="entry.tx"
            :href="txUrl(entry.tx)"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View transaction on Etherscan"
            title="View on Etherscan"
            icon="mdi-open-in-new"
            size="x-small"
            variant="plain"
            density="compact"
          />
        </div>
      </template>

      <!-- Custody offer declined by the proposed recipient -->
      <template v-else-if="entry.type === 'declined'">
        <div class="text-body-2 font-weight-bold">Custody Offer Declined</div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          {{ short(entry.to) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.to)" />
          declined offer from {{ short(entry.from) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.from)" />
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Block {{ entry.block }}
          <v-btn
            v-if="entry.tx"
            :href="txUrl(entry.tx)"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View transaction on Etherscan"
            title="View on Etherscan"
            icon="mdi-open-in-new"
            size="x-small"
            variant="plain"
            density="compact"
          />
        </div>
      </template>

      <!-- Custody accepted (step 2 of handoff) -->
      <template v-else-if="entry.type === 'transferred'">
        <div class="text-body-2 font-weight-bold">Custody Accepted</div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          {{ short(entry.from) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.from)" />
          → {{ short(entry.to) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.to)" />
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Block {{ entry.block }}
          <v-btn
            v-if="entry.tx"
            :href="txUrl(entry.tx)"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View transaction on Etherscan"
            title="View on Etherscan"
            icon="mdi-open-in-new"
            size="x-small"
            variant="plain"
            density="compact"
          />
        </div>
      </template>

      <!-- Certified -->
      <template v-else-if="entry.type === 'certified'">
        <div class="text-body-2 font-weight-bold">Batch Certified</div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Auditor: {{ short(entry.auditor) }}
          <v-btn icon="mdi-content-copy" aria-label="Copy address" title="Copy address" size="x-small" variant="plain" density="compact" @click.stop="copy(entry.auditor)" />
        </div>
        <div class="text-caption text-medium-emphasis d-flex align-center ga-1">
          Block {{ entry.block }}
          <v-btn
            v-if="entry.tx"
            :href="txUrl(entry.tx)"
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View transaction on Etherscan"
            title="View on Etherscan"
            icon="mdi-open-in-new"
            size="x-small"
            variant="plain"
            density="compact"
          />
        </div>
      </template>

    </v-timeline-item>

  </v-timeline>
</template>

<script setup>
import { STATUS_COLORS } from '@/composables/useBatches'
import { useToastStore } from '@/stores/toast'
import { shortAddress as short } from '@/utils/address'

defineProps({
  entries: { type: Array, default: () => [] },
})

const toast = useToastStore()

// Single-network deployment (Sepolia) — keep it simple, no chain registry.
const EXPLORER_TX_BASE = 'https://sepolia.etherscan.io/tx/'
function txUrl(tx) {
  return EXPLORER_TX_BASE + tx
}

async function copy(addr) {
  if (!addr) return
  // navigator.clipboard is undefined on insecure (non-HTTPS, non-localhost) origins
  if (!navigator.clipboard) {
    toast.show('Clipboard unavailable on this connection.', 'warning')
    return
  }
  try {
    await navigator.clipboard.writeText(addr)
    toast.show('Address copied.', 'success')
  } catch {
    toast.show('Could not copy address.', 'error')
  }
}

function statusColor(label) {
  return STATUS_COLORS[label] ?? 'grey'
}

function dotColor(entry) {
  if (entry.type === 'created')     return 'green'
  if (entry.type === 'proposed')    return 'amber'
  if (entry.type === 'cancelled')   return 'red'
  if (entry.type === 'declined')    return 'red'
  if (entry.type === 'transferred') return 'orange'
  if (entry.type === 'certified')   return 'teal'
  return 'primary'
}
</script>
