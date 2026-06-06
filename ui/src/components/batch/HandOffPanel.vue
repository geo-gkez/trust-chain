<template>
  <div>
    <v-card max-width="480" class="pa-6 mb-4">
      <v-card-title class="mb-4">Hand Off Custody</v-card-title>
      <CustodyForm @done="onProposed" />
    </v-card>

    <v-card max-width="480" class="pa-6">
      <v-card-title class="mb-4">Your Pending Offers</v-card-title>
      <OutgoingCustody ref="outgoing" @cancelled="emit('done')" />
    </v-card>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import CustodyForm from './CustodyForm.vue'
import OutgoingCustody from './OutgoingCustody.vue'

const emit = defineEmits(['done'])
const outgoing = ref(null)

function onProposed(proposed) {
  // Show the new offer immediately from what we just submitted; the subgraph
  // hasn't indexed it yet, so a reload here would miss it.
  outgoing.value?.addOffer(proposed.serial, proposed.to)
}
</script>
