import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// In development the browser talks only to Vite, which forwards API calls and
// the WebSocket to Rails. The page and the API then share one origin, so the
// guest cookie works without any CORS setup.
const api = process.env.VITE_API_PROXY ?? "http://localhost:3000";

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5173,
    // File change events do not cross a Docker bind mount on Windows or macOS.
    watch: process.env.VITE_USE_POLLING ? { usePolling: true, interval: 300 } : undefined,
    proxy: {
      "/api": api,
      "/health": api,
      "/cable": { target: api, ws: true },
    },
  },
  test: {
    environment: "node",
    include: ["src/**/*.test.ts"],
  },
});
