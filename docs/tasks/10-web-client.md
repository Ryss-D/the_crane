# 10 — Customer web client (WEB) · Phase 4

Request and track a grúa from the browser — no install. Customer role only.

- [ ] **WEB-1 — Scaffold + generated API client** *(deps: JOB-5)*
  Vite + React + TS + Tailwind in `web-client/` (`web/` is Flutter's web target); Firebase Auth web (phone OTP); typed client generated from the FastAPI OpenAPI spec (`openapi-typescript`); CI check that the spec and client are in sync.
  *AC: login with a Firebase test number; typed calls to `/v1/me` work; CORS configured.*

- [ ] **WEB-2 — Request flow** *(deps: WEB-1, CUS parity)*
  Browser-geolocation pickup, Places dropoff, vehicle type, quote, confirm — mobile-first layout.
  *AC: full request lands in the same dispatch pipeline as the app.*

- [ ] **WEB-3 — Live tracking page** *(deps: WEB-1, TRK-1)*
  Active-job view over the shared WS with 10s polling fallback; status timeline + driver marker; cash confirmation + rating.
  *AC: socket kill switches to polling transparently.*

- [ ] **WEB-4 — Public share-track page `/t/{token}`** *(deps: TRK-6)*
  Read-only live map, no login; used by the Flutter "share trip" button too.
  *AC: opens logged-out on a phone browser; shows position/status/ETA only.*

- [ ] **WEB-5 — Deploy** *(deps: WEB-1)*
  Static hosting (Cloudflare Pages / Vercel), env per stage, web-restricted Maps key, API CORS allowlist.
  *AC: dev + prod URLs live behind HTTPS.*
