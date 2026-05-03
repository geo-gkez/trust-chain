import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useToastStore = defineStore('toast', () => {
  const visible = ref(false)
  const message = ref('')
  const color   = ref('success')

  function show(msg, c = 'success') {
    message.value = msg
    color.value   = c
    visible.value = true
  }

  return { visible, message, color, show }
})
