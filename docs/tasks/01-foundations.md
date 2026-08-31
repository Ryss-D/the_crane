# 01 — Foundations (FND) · Phase 0

Workspace scaffolding and the plumbing every other feature stands on.

- [ ] **FND-1 — Firebase project setup**
  Create Firebase project (dev + prod), enable Phone Auth (+57) and FCM, download platform configs, create service account for the backend.
  *AC: Flutter dev flavor signs in with a test phone number; backend service-account JSON available via env.*
  Progress: single project `the-crane-c6b86` created (dev doubling as prod for now — see PLAN.md decision log). Android (`com.thecrane.app`), iOS, and one shared Web app registered; `google-services.json`/`GoogleService-Info.plist` in place and verified with a real `pod install` + `flutter build ios`. Phone (+57) and Email/Password providers are enabled in the console, and an admin test user exists. Flutter's `AuthInterceptor`/`CraneSocket` fetch real ID tokens, and AUTH-3's phone-OTP UI is now built (screens + `AuthCubit`, tested against the fake gateway). `web-client`/`admin` have real Firebase Auth wired end to end (phone OTP + reCAPTCHA, email/password) behind `VITE_USE_MOCKS=false`. Backend service-account key obtained and verified live (`FIREBASE_CREDENTIALS_PATH`, gitignored `secrets/`) — real ID-token verification confirmed working against the actual project. Still needed to close this AC: an actual run against the live project's test number (`+57 300 0000000` / `123456`) with fakes turned off, end to end on a device/simulator — everything above is built and unit/widget-tested, just not yet exercised against the real backend in one live pass.

- [x] **FND-2 — Backend scaffold** *(deps: —)*
  FastAPI app per `backend/README.md` layout: `main.py`, `core/config.py` (pydantic-settings), `core/database.py` (async SQLAlchemy), Alembic init, health endpoint, Dockerfile.
  *AC: `docker compose up` serves `GET /health` 200; `alembic upgrade head` runs clean.*

- [x] **FND-3 — Local infra (Docker Compose)** *(deps: FND-2)*
  Compose file: api + `postgis/postgis` + `redis`. Seed script for a dev admin user and default `platform_config` values.
  *AC: one command brings up the full local stack with seeded config.*

- [x] **FND-4 — Flutter app restructure** *(deps: —)*
  Rework boilerplate into the feature-first layout (PLAN §3.2): `app/` (router, theme, providers), `core/` (api, ws, models), `features/`. Add flutter_bloc, go_router, dio, freezed, flavors (dev/prod via `--dart-define-from-file`).
  *AC: app builds both flavors; router shows a placeholder auth screen; codegen (`build_runner`) wired.*

- [x] **FND-5 — Firebase token verification middleware** *(deps: FND-2)*
  FastAPI dependency: `Authorization: Bearer <firebase_id_token>` → verified claims → `users` row (404 if not synced). Admin variant checks `role=admin`.
  *AC: protected route rejects missing/bad tokens (401), unknown users (404); test with emulator or mocked verifier.*

- [ ] **FND-6 — Google Maps keys & billing** *(deps: —)*
  Enable Maps SDKs (Android/iOS/JS), Places, Directions. Separate restricted keys per platform; bias Places to Valle de Aburrá.
  *AC: keys in env files per flavor; a map renders in the Flutter dev app.*

  Backend-side note: a **4th key** is also needed — server-side, scoped to Places
  API + Directions API, distinct from the Android/iOS/Web client keys. See the
  JOB-4 follow-up note in `03-jobs-pricing.md` for the new `/v1/places/*` +
  `/v1/directions/route` proxy endpoints this backs (`GOOGLE_MAPS_API_KEY` in
  `backend/.env.example`) — real, tested code, currently only exercising its
  no-key fallback path since that key doesn't exist yet either.

  Progress (2026-08-30): **Android and Web keys obtained and wired end to
  end; iOS deferred by choice** (the user will create it later — the code
  is ready and waiting, see below). Android key restricted to package
  `com.thecrane.app` + the local debug keystore's SHA-1 (release-build SHA-1
  still needs adding once a real release keystore exists); Web key
  restricted to `localhost:5173`/`5174` referrers only — **must be updated
  with the real prod domain(s) once `web-client`/`admin` deploy** (OPS-3/
  WEB-5), or prod requests get blocked. Both keys also set as GitHub Actions
  repo secrets (`MAPS_API_KEY_ANDROID`, `MAPS_API_KEY_WEB`) for whenever a
  real build/deploy step consumes them — nothing does yet.
  - Android: `android/local.properties` (gitignored) → `build.gradle`
    manifest placeholder (falls back to `MAPS_API_KEY_ANDROID` env var) →
    `AndroidManifest.xml`'s `com.google.android.geo.API_KEY`.
  - iOS: `ios/Runner/Info.plist`'s `GMSApiKey` is an empty-string placeholder;
    `AppDelegate.swift` already calls `GMSServices.provideAPIKey` reading it
    (a no-op on empty) — pasting the real key into that one plist entry is
    the *only* step left once the iOS key exists.
  - Web: `web-client/.env.local` + `admin/.env.local` (both gitignored) as
    `VITE_GOOGLE_MAPS_API_KEY`, documented in both `.env.example` files.

  Map integration built on top of this (Flutter side): `google_maps_flutter`
  added; a shared `CraneMap` widget (`lib/features/shared/widgets/crane_map.dart`)
  replaces `MapPlaceholder` in `RequestScreen` (CUS-1, with a `PlacesAutocompleteField`
  backed by the backend's new `/v1/places/*` proxy — see `06-customer-app.md`),
  `DriverHomeScreen` (DRV-1, static center, no live self-position yet),
  `HistoryDetailScreen` (RAT-3, static pickup/dropoff + route), and
  `ActiveJobScreen` (DRV-3, pickup/dropoff + route, see `07-driver-app.md`).
  Pin-drag is not built anywhere (search/fixed-pin only). `CraneMap` needs a
  device-independent test seam either way — `google_maps_flutter`'s
  `GoogleMap` throws `MissingPluginException` under `flutter_test` (no
  native host); `CraneMap.debugTestBuilder` + `test/flutter_test_config.dart`
  swap in a keyed-`Text` stand-in for every test, globally. Full suite green
  (395 passed, up from 391) but **not run on a real device/simulator** —
  nothing here has seen an actual rendered Google Map yet.

  Web-client side (built in parallel, see the WEB-2/3/4 follow-up notes in
  `10-web-client.md`): real `@vis.gl/react-google-maps` integration —
  draggable pickup/dropoff pins + Places Autocomplete on `RequestPage`, a
  live driver marker on `TrackingPage`/`ShareTrackPage`. Surfaced one real
  backend gap: `GET /v1/jobs/{id}` has no driver-location field at all — the
  authenticated tracking page's only live-position path is the
  `driver_location` WS event, which `useJobSocket` didn't consume before
  this and now does.
