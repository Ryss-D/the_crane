/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5174,
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.tsx'],
    css: false,
    // src/firebase.ts calls initializeApp/getAuth at module-eval time (via
    // src/auth/firebaseAuth.ts, imported unconditionally by singleton.ts
    // alongside FakeAuth) regardless of VITE_USE_MOCKS, so it needs a
    // non-empty apiKey to not throw even though tests always exercise the
    // FakeAuth path. Real dev/prod still comes from `.env.local` (untracked,
    // see `.env.example`) — these are just placeholders so CI and fresh
    // checkouts without that file don't crash before a single test runs.
    env: {
      VITE_FIREBASE_API_KEY: 'test-placeholder-api-key',
      VITE_FIREBASE_AUTH_DOMAIN: 'test.firebaseapp.com',
      VITE_FIREBASE_PROJECT_ID: 'test-project',
      VITE_FIREBASE_STORAGE_BUCKET: 'test.firebasestorage.app',
      VITE_FIREBASE_MESSAGING_SENDER_ID: '000000000000',
      VITE_FIREBASE_APP_ID: '1:000000000000:web:0000000000000000000000',
      // ADM-5 follow-up: OperationsMap checks for a truthy key before
      // rendering at all, and @vis.gl/react-google-maps itself is mocked
      // wholesale in src/test/setup.tsx, so this never reaches a real
      // network call; it just needs to be non-empty for that truthiness
      // check. Same reasoning as web-client's identical placeholder.
      VITE_GOOGLE_MAPS_API_KEY: 'test-placeholder-maps-key',
    },
  },
});
