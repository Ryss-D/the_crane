/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** "false" to hit the real backend; anything else (or unset) → mocks. */
  readonly VITE_USE_MOCKS?: string;
  readonly VITE_API_BASE_URL?: string;
  // TODO(FND-1): VITE_FIREBASE_* config keys.
  // TODO(FND-6): VITE_GOOGLE_MAPS_API_KEY.
}
