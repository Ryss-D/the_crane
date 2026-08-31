/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** "false" to hit the real backend; anything else (or unset) → mocks. */
  readonly VITE_USE_MOCKS?: string;
  readonly VITE_API_BASE_URL?: string;
  readonly VITE_FIREBASE_API_KEY?: string;
  readonly VITE_FIREBASE_AUTH_DOMAIN?: string;
  readonly VITE_FIREBASE_PROJECT_ID?: string;
  readonly VITE_FIREBASE_STORAGE_BUCKET?: string;
  readonly VITE_FIREBASE_MESSAGING_SENDER_ID?: string;
  readonly VITE_FIREBASE_APP_ID?: string;
  /** FND-6: web-restricted (HTTP referrer) key — Maps JavaScript API + Places API. */
  readonly VITE_GOOGLE_MAPS_API_KEY?: string;
  /** OPS-6: unset → Sentry.init is skipped entirely (see src/main.tsx). */
  readonly VITE_SENTRY_DSN?: string;
}
