<template>
  <div>
    <v-skeleton-loader v-if="loading" type="list-item-two-line@3" />

    <v-alert
      v-else-if="offers.length === 0"
      type="info"
      variant="tonal"
      density="comfortable"
      icon="mdi-inbox-outline"
    >
      No incoming custody offers. When another holder hands a batch off to you, it will appear here for acceptance.
    </v-alert>

    <v-list v-else lines="two">
      <v-list-item
        v-for="offer in offers"
        :key="offer.serial"
        :title="offer.serial"
      >
        <template #subtitle>
          Offered by {{ short(offer.from) }}
        </template>
        <template #append>
          <div class="d-flex ga-2">
            <v-btn
              color="success"
              variant="tonal"
              size="small"
              :loading="accepting === offer.serial"
              :disabled="declining === offer.serial"
              @click="accept(offer.serial)"
            >
              Accept
            </v-btn>
            <v-btn
              color="error"
              variant="tonal"
              size="small"
              :loading="declining === offer.serial"
              :disabled="accepting === offer.serial"
              @click="decline(offer.serial)"
            >
              Decline
            </v-btn>
          </div>
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
import { shortAddress as short } from '@/utils/address'

const emit = defineEmits(['accepted'])

const { fetchPendingCustody, acceptCustody, declineCustody } = useBatches()
const toast = useToastStore()
const wallet = useWalletStore()

const offers    = ref([])
const loading   = ref(false)
const accepting = ref(null)
const declining = ref(null)

async function load() {
  loading.value = true
  try   { offers.value = await fetchPendingCustody() }
  catch { toast.show('Failed to load incoming custody offers.', 'error') }
  finally { loading.value = false }
}

async function accept(serial) {
  accepting.value = serial
  try {
    await acceptCustody(serial)
    toast.show(`Custody of ${serial} accepted.`, 'success')
    await load()
    emit('accepted')
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    accepting.value = null
  }
}

async function decline(serial) {
  declining.value = serial
  try {
    await declineCustody(serial)
    toast.show(`Custody offer for ${serial} declined.`, 'success')
    await load()
    emit('accepted')
  } catch (err) {
    toast.show(err.message, 'error')
  } finally {
    declining.value = null
  }
}

onMounted(load)
// Refresh when the connected account changes (e.g. MetaMask account switch),
// even between two accounts of the same role where the dashboard doesn't remount.
watch(() => wallet.account, load)
defineExpose({ load })
</script>
