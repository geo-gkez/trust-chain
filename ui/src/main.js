import { createApp } from 'vue'
import { createPinia } from 'pinia'
import vuetify from './plugins/vuetify'
import router from './router'
import App from './App.vue'
import { useWalletStore } from '@/stores/wallet'

const app   = createApp(App)
const pinia = createPinia()

app.use(pinia).use(vuetify)

// Restore an existing wallet session (no popup) before the router's auth guard
// runs, so a direct load of a protected route isn't bounced to home.
await useWalletStore(pinia).autoConnect()

app.use(router)
app.mount('#app')
