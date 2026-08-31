import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The Flutter app POSTs to mpesa-backend on :5000, which is also where the
// dashboard reads from. Proxying in dev keeps the browser same-origin, so the
// socket handshake and the REST calls need no CORS negotiation.
const BACKEND = process.env.MPESA_BACKEND ?? 'http://localhost:5000';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: BACKEND, changeOrigin: true },
      '/socket.io': { target: BACKEND, changeOrigin: true, ws: true },
    },
  },
});
