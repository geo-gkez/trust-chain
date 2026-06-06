import 'vuetify/styles'
import '@mdi/font/css/materialdesignicons.css'
import { createVuetify } from 'vuetify'
import { aliases, mdi } from 'vuetify/iconsets/mdi'

export default createVuetify({
  icons: {
    defaultSet: 'mdi',
    aliases,
    sets: { mdi },
  },
  theme: {
    defaultTheme: 'trustChainTheme',
    themes: {
      trustChainTheme: {
        dark: true,
        colors: {
          primary:   '#7C3AED',
          secondary: '#6B7280',
        },
      },
    },
  },
})
