import 'vuetify/styles'
import '@mdi/font/css/materialdesignicons.css'
import { createVuetify } from 'vuetify'

const trustChainTheme = {
  dark: true,
  colors: {
    background: '#0d1117',
    surface: '#161b22',
    'surface-variant': '#21262d',
    primary: '#238636',
    'primary-darken-1': '#1a6e2a',
    secondary: '#1f6feb',
    'secondary-darken-1': '#1158c7',
    error: '#f85149',
    info: '#58a6ff',
    success: '#3fb950',
    warning: '#d29922',
    'status-produced': '#6e7681',
    'status-stored': '#1f6feb',
    'status-in-transit': '#d29922',
    'status-distributed': '#3fb950',
    'status-recalled': '#f85149',
    'status-disposed': '#8957e5',
  },
}

export default createVuetify({
  theme: {
    defaultTheme: 'trustChainTheme',
    themes: { trustChainTheme },
  },
  icons: {
    defaultSet: 'mdi',
  },
})
