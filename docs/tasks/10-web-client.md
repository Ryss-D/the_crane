# 10 — Customer web client (WEB) · Phase 4

Request and track a grúa from the browser — no install. Customer role only.

- [ ] **WEB-1 — Scaffold + generated API client** *(deps: JOB-5)*
  Vite + React + TS + Tailwind in `web-client/` (`web/` is Flutter's web target); Firebase Auth web (phone OTP); typed client generated from the FastAPI OpenAPI spec (`openapi-typescript`); CI check that the spec and client are in sync.
  *AC: login with a Firebase test number; typed calls to `/v1/me` work; CORS configured.*
  Built: Vite + React + TS + Tailwind scaffold; real `FirebaseAuthClient` (phone-OTP, `RecaptchaVerifier`) selected via `VITE_USE_MOCKS` alongside `FakeAuth`; `HttpApi` fetch client whose paths match the backend exactly (`POST /v1/jobs/quote`, `POST /v1/jobs`, `GET /v1/jobs/{id}`, `GET /v1/track/{token}` -- checked path-for-path against `backend/app/api/jobs.py`); `.github/workflows/web-client.yml` runs lint/test/build on every PR touching `web-client/`. Fixed: `backend/app/main.py` now has `CORSMiddleware` (`CORS_ORIGINS` env var, defaults to both apps' local Vite dev servers), tested (`backend/tests/test_cors.py`). Not done: `npm run client:generate` is a literal TODO stub, so `src/api/types.ts` is still hand-written (it has already drifted from the real contract twice -- see the "align Job/TrackInfo" fix commits -- with no CI check to catch the next drift); the app never calls `GET/PATCH /v1/me` or `POST /v1/auth/sync` anywhere; no manual pass against a real Firebase test number for the web client specifically (only the Flutter app's AUTH-3 note covers that).

- [ ] **WEB-2 — Request flow** *(deps: WEB-1, CUS parity)*
  Browser-geolocation pickup, Places dropoff, vehicle type, quote, confirm — mobile-first layout.
  *AC: full request lands in the same dispatch pipeline as the app.*
  Built: vehicle-type selector, quote, confirm and redirect-to-tracking all wired through the `CraneApi` seam and covered end to end (mock path) by `RequestPage.test.tsx`. Fixed: the real request-shape mismatch flagged below -- `QuoteRequest`/`CreateJobRequest` now send `pickup`/`dropoff` as `{lat, lng}` (`{lat, lng, address}` for job creation), matching `backend/app/schemas/job.py` exactly, via a new `fakeGeocode` helper (`src/api/geocode.ts`, mirrors the Flutter app's approach, own test file) that derives a point from the typed address until FND-6 lands. Not done: pickup/dropoff are still plain text inputs behind a `TODO(FND-6)` placeholder box -- no browser geolocation, no Places autocomplete. Still not verified against a live backend end to end (CORS + the payload shape were the two known blockers; both are fixed now, but nobody's actually run it against a real server yet).

- [ ] **WEB-3 — Live tracking page** *(deps: WEB-1, TRK-1)*
  Active-job view over the shared WS with 10s polling fallback; status timeline + driver marker; cash confirmation + rating.
  *AC: socket kill switches to polling transparently.*
  Built: status timeline + driver card render off the shared job/track data, 10s polling via TanStack Query `refetchInterval`, share-link copy button, local ratings stub on completion; 5 tests passing in `TrackingPage.test.tsx`. Fixed: `job.driver` was flagged as broken against the real backend (`JobRead` only returned `driver_id`) -- backend now populates it (JOB-5's `_job_read`), and `Driver`/`DriverCard` were updated to the real field names (`truck_plate`/`truck_type`/`rating_avg`/`photo_url`, matching the backend's `JobDriverInfo` and the Flutter app's `JobDriverSummary` exactly) instead of the made-up `rating`/`plate`/`truck_description` shape invented before the contract existed. Also built: a "pagado en efectivo" cash-confirmation button on `delivered` (`CraneApi.confirmDelivery` -> `POST /v1/jobs/{id}/confirm-delivery`, mirrors the Flutter app's CUS-5), and `MockApi` no longer lets a job auto-complete purely from elapsed time -- only an explicit confirm moves it to `completed`, matching the backend restricting completion to the customer. Not done: `src/ws/useJobSocket.ts` is a documented no-op stub -- there is no real WebSocket, so the "socket kill switches to polling transparently" AC can't be exercised at all (nothing to kill); `RatingStub` is still local-only and never POSTs to a real ratings endpoint.

- [x] **WEB-4 — Public share-track page `/t/{token}`** *(deps: TRK-6)*
  Read-only live map, no login; used by the Flutter "share trip" button too.
  *AC: opens logged-out on a phone browser; shows position/status/ETA only.*
  Built: routed at `/t/:token` in `App.tsx`; `ShareTrackPage.tsx` fetches via the real `CraneApi.getTrack` seam to `GET /v1/track/{share_token}`, confirmed against `backend/app/api/jobs.py`'s `track_router` and the `TrackResponse`/`TrackDriver` schemas in `backend/app/schemas/job.py` -- shapes match exactly, no auth. Tests cover both the found case (seeded demo token, nested driver fields) and the not-found/expired-token case (added this session), both in `TrackingPage.test.tsx`. No live map yet (still the `TODO(FND-6)` placeholder box, same as the other tracking pages) -- ETA is intentionally absent since the backend's `TrackResponse` doesn't compute one. lint/test/build all clean.

- [ ] **WEB-5 — Deploy** *(deps: WEB-1)*
  Static hosting (Cloudflare Pages / Vercel), env per stage, web-restricted Maps key, API CORS allowlist.
  *AC: dev + prod URLs live behind HTTPS.*
