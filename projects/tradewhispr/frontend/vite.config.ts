import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { fileURLToPath, URL } from "node:url";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: {
    port: 5173,
    host: true,
    allowedHosts: ["tradewhispr.local", "localhost", ".local", "tradewhispr-frontend-dev"],
    proxy: {
      "/api": {
        target: "http://backend:8000",
        changeOrigin: true,
      },
    },
    hmr: {
      // Use WSS for HMR through Traefik HTTPS
      protocol: "wss",
      clientPort: 443,
    },
    watch: {
      usePolling: true,
      interval: 100,
    },
  },
});
