import { fileURLToPath, URL } from 'node:url'
import path from 'node:path'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vuetify from 'vite-plugin-vuetify'

const __dirname = fileURLToPath(new URL('.', import.meta.url))

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    vuetify({ autoImport: true }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      '@trustchain-abi': path.resolve(__dirname, '../contracts/out/TrustChain.sol/TrustChain.json'),
    },
  },
  server: {
    host: '0.0.0.0',
    fs: {
      allow: ['..'],
    },
  },
})
