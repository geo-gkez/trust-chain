<template>
  <v-chip
    v-if="roleLabel"
    :color="roleColor"
    size="small"
    variant="tonal"
    prepend-icon="mdi-shield-account"
  >
    {{ roleLabel }}
  </v-chip>
</template>

<script setup>
import { useUserRole } from '@/composables/useUserRole'

const { roleLabel, roleColor } = useUserRole()
</script>
