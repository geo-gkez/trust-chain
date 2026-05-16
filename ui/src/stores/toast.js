import { defineStore } from 'pinia'

export const useToastStore = defineStore('toast', {
  state: () => ({
    message: '',
    color:   'success',
    visible: false,
  }),
  actions: {
    show(message, color = 'success') {
      this.message = message
      this.color   = color
      this.visible = true
    },
  },
})
