import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import * as Sentry from '@sentry/react';
import App from './App';
import './index.css';

// OPS-6: unset/empty is a valid, silent no-op state, same convention as
// VITE_GOOGLE_MAPS_API_KEY's own conditional-render checks in web-client -- @sentry
// /react's own init already no-ops on a falsy dsn, but the call is guarded
// explicitly rather than relying on that. No real Sentry account exists yet, so
// this branch is never taken outside tests.
if (import.meta.env.VITE_SENTRY_DSN) {
  Sentry.init({
    dsn: import.meta.env.VITE_SENTRY_DSN,
    environment: import.meta.env.MODE,
  });
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
