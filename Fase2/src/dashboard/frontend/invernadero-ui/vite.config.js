import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import process from 'node:process'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const apiBaseUrl =
    env.VITE_API_BASE_URL ||
    'http://localhost:5000/api/invernadero'
  const apiProxyTarget = new URL(apiBaseUrl).origin

  return {
    plugins: [react(), tailwindcss()],
    server: {
      proxy: {
        '/api': apiProxyTarget
      }
    }
  }
})
