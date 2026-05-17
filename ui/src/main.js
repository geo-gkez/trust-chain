import { createApp } from 'vue'
import { createPinia } from 'pinia'
import vuetify from './plugins/vuetify'
import router from './router'
import App from './App.vue'

createApp(App)
  .use(createPinia())
  .use(vuetify)
  .use(router)
  .mount('#app')
