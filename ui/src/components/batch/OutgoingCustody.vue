<template>
  <div>
    <v-skeleton-loader v-if="loading" type="list-item-two-line@2" />

    <v-alert
      v-else-if="offers.length === 0"
      type="info"
      variant="tonal"
      density="comfortable"
      icon="mdi-send-outline"
    >
      No pending offers. Custody hand-offs you propose appear here until the recipient accepts — you can cancel them while they wait.
    </v-alert>

    <v-list v-else lines="two">
      <v-list-item
        v-for="offer in offers"
        :key="offer.serial"
        :title="offer.serial"
      >
        <template #subtitle>
          Offered to {{ short(offer.to) }} — awaiting acceptance
        </template>
        <template #append>
          <v-btn
            color="error"
            variant="tonal"
            size="small"
            :loading="cancelling === offer.serial"
            @click="cancel(offer.serial)"
          >
            Cancel
          </v-btn>
        </template>
      </v-list-item>
    </v-list>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useBatches } from '@/composables/useBatches'
import { useToastStore } from '@/stores/toast'
import { useWalletStore } from '@/stores/wallet'

const emit = defineEmits(['cancelled'])

const { fetchOutgoingCustody, cancelCustody } = useBatches()
const toast = useToastStore()
const wallet = useWalletStore()

const offers     = ref([])
const loading    = ref(false)
const cancelling = ref(null)

async function load() {
  loading.value = true
  try   { offers.value = await fetchOutgoingCustody() }
  catch { toast.show('Failed to load your pending offers.', 'error') }
  finally { loading.value = false }
}

async function cancel(serial) {
  cancelling.value = serial
  try {
    await cancelCustody(serial)
    toast.show(`Hand-off offer for ${serial} cancelled.`, 'success')
    await load()
    emit('cancelled')
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    cancelling.value = null
  }
}

function short(addr) {
  if (!addr) return '—'
  return addr.slice(0, 6) + '…' + addr.slice(-4)
}

onMounted(load)
// Refresh when the connected account changes (same-role MetaMask switch included).
watch(() => wallet.account, load)
defineExpose({ load })
</script>
