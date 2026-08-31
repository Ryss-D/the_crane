# 10 — Customer web client (WEB) · Phase 4

Request and track a grúa from the browser — no install. Customer role only.

- [ ] **WEB-1 — Scaffold + generated API client** *(deps: JOB-5)*
  Vite + React + TS + Tailwind in `web-client/` (`web/` is Flutter's web target); Firebase Auth web (phone OTP); typed client generated from the FastAPI OpenAPI spec (`openapi-typescript`); CI check that the spec and client are in sync.
  *AC: login with a Firebase test number; typed calls to `/v1/me` work; CORS configured.*
  Built: Vite + React + TS + Tailwind scaffold; real `FirebaseAuthClient` (phone-OTP, `RecaptchaVerifier`) selected via `VITE_USE_MOCKS` alongside `FakeAuth`; `HttpApi` fetch client whose paths match the backend exactly (`POST /v1/jobs/quote`, `POST /v1/jobs`, `GET /v1/jobs/{id}`, `GET /v1/track/{token}` -- checked path-for-path against `backend/app/api/jobs.py`); `.github/workflows/web-client.yml` runs lint/test/build on every PR touching `web-client/`. Fixed: `backend/app/main.py` now has `CORSMiddleware` (`CORS_ORIGINS` env var, defaults to both apps' local Vite dev servers), tested (`backend/tests/test_cors.py`). Also fixed: the app now calls `POST /v1/auth/sync` (AUTH-2) once per sign-in -- `CraneApi.syncAuth()` (`src/api/client.ts`/`src/api/mock.ts`), triggered from a `useEffect` keyed on the Firebase uid in `AuthProvider` (`src/auth/AuthProvider.tsx`), tested in `src/auth/AuthProvider.test.tsx` (fires once per sign-in, not on unrelated re-renders, re-fires after sign-out + a different sign-in) and `src/api/mock.test.ts`. This closes the real gap where a fresh customer's first authenticated call (e.g. `POST /v1/jobs/quote`) would 404 with "User not found" from `get_current_user`. Deliberately did NOT build a profile-completion gate: `syncAuth()`'s response can come back with `name: null` (Firebase phone auth never provides one) and this web client has no equivalent of the Flutter app's `AuthPhase.needsProfile` / `complete_profile_screen.dart` -- a customer can currently request a tow with no name on file. Judged that adding a real gate (new phase, screen, `PATCH /v1/me` wiring) is a scope expansion beyond this fix; flagging it here rather than skipping silently. `GET`/`PATCH /v1/me` were NOT added to `CraneApi` -- no UI consumer exists yet (that's exactly the profile-completion gap above), so it would be unused plumbing; add them when that gate gets built. Also built this session: `npm run client:generate` actually works now (was a literal `echo ... && exit 1` stub) -- `openapi-typescript` (new devDependency) generates `src/api/generated.ts` from a checked-in `backend/openapi.json` snapshot (not a live server: `FastAPI.openapi()` needs no DB/Redis, just route registration at import time, so `backend/scripts/dump_openapi.py` dumps it with nothing more than `uv sync` -- see its docstring). Chose the smaller-but-still-valuable depth over a full `types.ts` replacement: kept `types.ts` hand-written, added `npm run client:check` (regenerates to a temp file, fails on diff) as the CI-checkable drift guard, wired into both `.github/workflows/web-client.yml` (`client:check` against the committed snapshot + generated file) and `.github/workflows/backend.yml` (re-dumps the spec, diffs against the committed snapshot -- catches the *other* half of drift, backend code vs. snapshot). Neither CI job needs a live server or service containers. Full rationale and the exact commands in `src/api/README.md`. A full `types.ts` -> generated-types migration (every hand-written interface remapped onto `components['schemas'][...]`, across every consumer) is flagged there as the natural next step, not done here -- bigger and riskier than fit alongside this session's other two tasks (WEB-2 geolocation, the tracking-page call button). No manual pass against a real Firebase test number for the web client specifically (only the Flutter app's AUTH-3 note covers that).

  Follow-up: the profile-completion gate flagged above as deliberately not
  built is built now. `CraneApi` gained `updateMe(body: {name?, email?})` ->
  `PATCH /v1/me` (`HttpApi`'s `request` now also accepts `'PATCH'`;
  `MockApi.updateMe` merges into its in-memory `userProfile`), matching
  `UserUpdate`/`UserRead` in `backend/app/schemas/user.py` exactly.
  `AuthProvider` now stores `syncAuth()`'s response as `profile` (previously
  discarded) and exposes it plus a `completeProfile(name)` action through
  `useAuth()`. `RequestPage` gates on it, mirroring the Flutter app's
  `AuthPhase.needsProfile`: renders nothing while `profile` is still null
  (sync in flight), a new `CompleteProfileForm` (name field, same copy as
  the Flutter app's `completeProfile*` ARB strings) while `profile.name` is
  null, and the real request form once a name is on file. `ShareTrackPage`/
  `TrackingPage` are deliberately NOT gated -- a customer can still reach an
  *existing* job's tracking page (e.g. a bookmarked `/jobs/:id`) without a
  name on file, only the create-a-new-job flow is blocked; judged
  acceptable since the AC and the original gap both talk about the request
  flow specifically.

  Surfaced and fixed a real test-isolation bug while adding coverage for
  this: `MockApi` is a module-level singleton shared by every test in a
  vitest file, and its `userProfile` field previously only ever got set
  once and then reused verbatim by every subsequent `syncAuth()` call
  (mirroring the backend's real create-or-fetch semantics) -- fine before
  this change, but once one test's `completeProfile()` gave it a name,
  every later test in the same file silently inherited that name and never
  saw the gate at all. Added `MockApi.resetForTests()` (not part of the
  `CraneApi` interface -- test-only) and call it from `src/test/setup.ts`'s
  existing `afterEach` (which already resets the `FakeAuth` singleton the
  same way). New tests: `RequestPage.profileGate.test.tsx` (mocks `useAuth`
  directly rather than going through the real singleton, so each case can
  assert an exact profile shape without depending on suite order) covers
  the null-profile loading state, the gate showing/submitting/erroring, and
  the gate being skipped when a name is already on file; `RequestPage.test.tsx`'s
  existing sign-in flows now complete the profile too (a fresh mock
  identity always needs it) via an extended `signIn()` helper. Full suite
  green (69 passed, up from 60), lint clean, `npm run build` clean.

  Still not checked off: no live pass against a real Firebase test number
  or a real backend for the web client (same standing gap as the rest of
  this task), and the `types.ts` -> generated-types migration flagged
  above is still not done.

  Follow-up (UX fix): the profile-completion gate above blocked the entire
  `RequestPage` behind sign-in -- a customer couldn't even see the map or
  get a price without giving a phone number first. Moved the gate: the
  backend's `/v1/jobs/quote` is now public (see `03-jobs-pricing.md`'s JOB-4
  follow-up), so `RequestPage` no longer gates on `user`/`profile` at page
  load at all -- the form, map and "Cotizar" button are always visible, and
  `PhoneSignIn`/`CompleteProfileForm` only appear inline once the customer
  presses **Confirm** without a usable identity yet (new `awaitingAuth`
  state). A `useEffect` watches for that identity completing while a quote
  is still held and fires `createMutation.mutate()` on its own, so signing
  in mid-flow doesn't lose the quote or need a second button press;
  clearing the quote (editing an address, picking a new one) resets
  `awaitingAuth` so a stale gate can't reappear on the next quote. Booking
  itself (`create_job`) still requires auth, unchanged -- only quoting
  moved. Caught and fixed one real bug while building this: the effect's
  dependency array initially included the `createMutation` object itself,
  which react-query returns as a fresh reference every render -- caused an
  infinite render loop (caught by a hung `vitest run`, not by the tests
  themselves passing/failing). Fixed by depending only on the primitives
  that actually need to retrigger it (`quote`, `awaitingAuth`, `user`,
  `profile`) and calling `.mutate()` from inside without depending on the
  object, same pattern as the effect's cleanup guard.

  `RequestPage.profileGate.test.tsx` rewritten for the new confirm-time
  gate (form renders immediately with no user/profile; sign-in and
  completion widgets only appear after Confirm; booking proceeds straight
  through when a name is already on file). `RequestPage.test.tsx`'s
  sign-in helper split into `requestQuote()` (no auth involved) and
  `confirmSigningIn()` (drives the post-Confirm gate), and the
  geolocation/map tests no longer sign in at all since none of them touch
  Confirm. Full web-client suite green (72 passed, up from 71), lint
  clean, `npm run build` clean.

  Not yet verified: no live pass against a real backend (same standing gap
  as above) -- this was all exercised against `MockApi`.

- [ ] **WEB-2 — Request flow** *(deps: WEB-1, CUS parity)*
  Browser-geolocation pickup, Places dropoff, vehicle type, quote, confirm — mobile-first layout.
  *AC: full request lands in the same dispatch pipeline as the app.*
  Built: vehicle-type selector, quote, confirm and redirect-to-tracking all wired through the `CraneApi` seam and covered end to end (mock path) by `RequestPage.test.tsx`. Fixed: the real request-shape mismatch flagged below -- `QuoteRequest`/`CreateJobRequest` now send `pickup`/`dropoff` as `{lat, lng}` (`{lat, lng, address}` for job creation), matching `backend/app/schemas/job.py` exactly, via a new `fakeGeocode` helper (`src/api/geocode.ts`, mirrors the Flutter app's approach, own test file) that derives a point from the typed address until FND-6 lands. Also built this session: a "usar mi ubicación actual" button next to the pickup field, using `navigator.geolocation.getCurrentPosition()` -- a free, standard Web API, no Maps key needed (unlike Places autocomplete or reverse-geocoding, which do). Chose option (b) from the WEB-2 backlog note over the plainer "just stuff coordinates into the text field": the real GPS fix is kept in its own `pickupCoords` state, separate from the `pickup` text field, and gets passed straight through to `quote()`/`createJob()` instead of `fakeGeocode`'s hash-derived point -- a real fix beats a fake one when we have it. The text field still shows the raw `(lat, lng)` (no reverse-geocoding available without a Maps key), and `pickupCoords` is cleared the moment the user edits the field by hand, so a manually-typed address always falls back to `fakeGeocode` correctly. Permission-denied/unavailable is handled without crashing -- clears the loading state and shows a brief `role="alert"` message, field stays untouched. Covered by three new tests in `RequestPage.test.tsx` (success fills the field with real coordinates, denial shows the message and leaves the field empty, manual edit after a GPS fix correctly falls back). Added a `navigator.geolocation` mock to `src/test/setup.ts` (jsdom doesn't implement it) -- exported as `mockGeolocation` so tests drive success/failure per case. Not done: pickup/dropoff are still plain text inputs otherwise, behind a `TODO(FND-6)` placeholder box -- no Places autocomplete (needs the Maps key), no way to geolocate the *dropoff*. Still not verified against a live backend end to end (CORS + the payload shape were the two known blockers; both are fixed now, but nobody's actually run it against a real server yet).

  Follow-up: FND-6 landed (`VITE_GOOGLE_MAPS_API_KEY`, web-restricted --
  Maps JavaScript API + Places API only, HTTP-referrer-locked to
  `localhost:5173`/`5174`), and the placeholder box is a real map now.
  `@vis.gl/react-google-maps` (new dependency, matches
  `docs/wiki/Technology-Stack.md`'s existing choice), via two new
  components: `RequestMap` (draggable "A"/"B" pins for pickup/dropoff --
  legacy `Marker`, not `AdvancedMarker`, since the latter needs a Map ID
  from Cloud Console's Map Management that doesn't exist yet) and
  `TrackingMap` (read-only, shared with WEB-3/WEB-4 below). Places
  Autocomplete has no ready-made component in that library, so a new
  `usePlacesAutocomplete` hook attaches the vanilla `google.maps.places
  .Autocomplete` widget directly to the existing pickup/dropoff `<input>`
  refs (`componentRestrictions: {country: 'co'}` + a Valle de Aburrá bounds
  bias) -- selecting a suggestion, or dragging a pin, now sets a real
  `dropoffCoords` (new; pickup already had `pickupCoords` from the GPS
  button, dropoff never did) that `quote()`/`createJob()` prefer over
  `fakeGeocode`, same pattern the GPS fix already established. A dragged
  pin's text-field label is the raw `(lat, lng)`, same as the GPS button's
  existing behavior -- real reverse geocoding would need the (unenabled)
  Geocoding API, not attempted here.

  Testing: no fake-map precedent existed in this codebase yet.
  `@vis.gl/react-google-maps` is mocked wholesale in `src/test/setup.tsx`
  (renamed from `.ts` -- it now has JSX) since it loads the real Maps JS API
  via a live `<script>` tag jsdom can't run: `APIProvider`/`Map` just render
  their children, `Marker` renders a `<div data-testid="map-marker">`
  exposing `position`/`label`/`title` as `data-*` attributes so tests can
  assert exactly which pins exist and where, and `useMapsLibrary` returns
  `null` (matching the real "library not loaded" state, so
  `usePlacesAutocomplete` safely no-ops in tests). `VITE_GOOGLE_MAPS_API_KEY`
  got a placeholder in `vite.config.ts`'s test env, same reasoning as the
  existing Firebase ones. New tests in `RequestPage.test.tsx`: no marker
  before any real coordinate exists, a pickup marker with the right
  lat/lng once the GPS button fires, and the dashed placeholder still
  showing when the key is unset (`vi.stubEnv`). Full suite green (71
  passed, up from 69), lint clean, `npm run build` clean.

  Not yet verified: no live pass against the real deployed key/domain (it's
  `localhost`-referrer-restricted only right now -- see the FND-6 memory
  note about updating that at deploy time), and no manual test of drag
  interactions or the real Autocomplete dropdown UI (jsdom + the mock above
  can't exercise real Google Maps JS at all, by design).

- [ ] **WEB-3 — Live tracking page** *(deps: WEB-1, TRK-1)*
  Active-job view over the shared WS with 10s polling fallback; status timeline + driver marker; cash confirmation + rating.
  *AC: socket kill switches to polling transparently.*
  Built: status timeline + driver card render off the shared job/track data, 10s polling via TanStack Query `refetchInterval`, share-link copy button; 5 tests passing in `TrackingPage.test.tsx`. Fixed: `job.driver` was flagged as broken against the real backend (`JobRead` only returned `driver_id`) -- backend now populates it (JOB-5's `_job_read`), and `Driver`/`DriverCard` were updated to the real field names (`truck_plate`/`truck_type`/`rating_avg`/`photo_url`, matching the backend's `JobDriverInfo` and the Flutter app's `JobDriverSummary` exactly) instead of the made-up `rating`/`plate`/`truck_description` shape invented before the contract existed. Also built: a "pagado en efectivo" cash-confirmation button on `delivered` (`CraneApi.confirmDelivery` -> `POST /v1/jobs/{id}/confirm-delivery`, mirrors the Flutter app's CUS-5, `MockApi` no longer lets a job auto-complete purely from elapsed time), `RatingStub` now actually posts via `CraneApi.submitRating` -> `POST /v1/jobs/{id}/rating` (RAT-1) instead of being a local-only stub, and `useJobSocket` is a real client now (was a hardcoded no-op stub) -- connects to the authed `/v1/ws` (TRK-1), subscribes to the job, invalidates the TanStack Query cache on `job_event`, reconnects on close/error, matching the protocol documented in `backend/app/api/ws.py`. No-ops entirely under mocks (nothing to connect to) -- polling stays as the unconditional permanent fallback either way, per the plan. Not covered by an automated test (no fake-WebSocket harness in this codebase, no live server to verify against) -- needs a real manual pass before checking this off, same caveat every real-backend-only path in this session has. Also built this session: a call-driver button on `DriverCard.tsx` (a plain `<a href="tel:...">`, no new dependency -- native HTML), parity with the Flutter app's CUS-4 (`matching_screen.dart`, `url_launcher`'s `tel:` scheme). Shown only when `driver.phone` is non-null (backend already had this field; the web client just never surfaced it). Covered by `DriverCard.test.tsx` (link present/absent) and an assertion in `TrackingPage.test.tsx`'s existing driver-card test.

  Follow-up: the map is real now, and a genuine backend-data gap surfaced
  while wiring it. `TrackingMap` renders pickup/dropoff pins off the job's
  own `pickup_lat`/`pickup_lng`/`dropoff_lat`/`dropoff_lng` -- which the
  real `JobRead` (`backend/app/schemas/job.py`) has always returned, but
  this web client's hand-written `Job` type (`src/api/types.ts`) never
  declared, so `HttpApi.getJob`'s plain passthrough was silently dropping
  them from the typed view. Added the four fields to the type (zero runtime
  change needed against the real backend) and to `MockApi`'s job records.
  The driver marker is the real backend gap: `GET /v1/jobs/{id}` (`JobRead`)
  has *no location field at all* -- only the public `GET /v1/track/{token}`
  (`TrackResponse.driver_location`) does. The backend does push a
  `driver_location` WS event on both the authed job channel and the public
  track channel (`DriverLocationEvent`, same file), so `useJobSocket`
  (previously only handling `ping`/`job_event`) now also listens for it and
  exposes the latest fix as `driverLocation` -- this is the *only* path to
  a live driver position on the authenticated tracking page; there is no
  REST fallback for it today. Icon: a small amber square marker (no
  driver-truck icon asset exists in this codebase to reach for). New tests
  in `TrackingPage.test.tsx`: two pickup/dropoff markers with the job's own
  coordinates, no driver marker under mocks (nothing pushes a
  `driver_location` WS event there, matching the honest gap above). Full
  suite green (see WEB-2's note for the count), lint clean, build clean.

  Not yet verified: no live pass against a real backend/WS connection --
  same standing gap as the rest of WEB-3, now extended to the
  `driver_location` handling specifically.

- [x] **WEB-4 — Public share-track page `/t/{token}`** *(deps: TRK-6)*
  Read-only live map, no login; used by the Flutter "share trip" button too.
  *AC: opens logged-out on a phone browser; shows position/status/ETA only.*
  Built: routed at `/t/:token` in `App.tsx`; `ShareTrackPage.tsx` fetches via the real `CraneApi.getTrack` seam to `GET /v1/track/{share_token}`, confirmed against `backend/app/api/jobs.py`'s `track_router` and the `TrackResponse`/`TrackDriver` schemas in `backend/app/schemas/job.py` -- shapes match exactly, no auth. Tests cover both the found case (seeded demo token, nested driver fields) and the not-found/expired-token case (added this session), both in `TrackingPage.test.tsx`. No live map yet (still the `TODO(FND-6)` placeholder box, same as the other tracking pages) -- ETA is intentionally absent since the backend's `TrackResponse` doesn't compute one. lint/test/build all clean.

  Follow-up: the map is real now, and unlike WEB-3's authenticated page,
  this one needed no WS work at all -- `TrackResponse.driver_location` is
  already part of the poll response `getTrack()` returns every 10s, so
  `TrackingMap` (shared with WEB-3) just reads `track.pickup`/
  `track.dropoff`/`track.driver_location` directly. New test in
  `TrackingPage.test.tsx`: three markers (pickup, dropoff, driver) once a
  driver is assigned on the seeded demo token. Full suite green, lint
  clean, build clean. Not yet verified against a real deployed key/domain,
  same as WEB-2/WEB-3.

- [ ] **WEB-5 — Deploy** *(deps: WEB-1)*
  Static hosting (Cloudflare Pages / Vercel), env per stage, web-restricted Maps key, API CORS allowlist.
  *AC: dev + prod URLs live behind HTTPS.*

  Doc cross-reference: this work was actually done and recorded under
  `13-devops.md`'s **OPS-5** (Fly.io, not the Cloudflare Pages/Vercel this
  line originally named — see that entry for the full rationale/history)
  rather than here, so it never got cross-linked. AC is partially met: dev
  is live behind HTTPS (`https://the-crane-web.fly.dev`), web-restricted
  Maps key and CORS allowlist both in place; no separate prod URL exists
  yet, matching OPS-3/OPS-5's own deliberate dev-only scope. Left unchecked
  here for that reason, not because the work doesn't exist.
