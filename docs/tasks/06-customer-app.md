# 06 — Customer mobile flows (CUS) · Phase 1–2

Flutter customer shell: request a tow, follow it live, confirm delivery.

- [ ] **CUS-1 — Request screen: map + location pickers** *(deps: AUTH-4, FND-6)*
  Map centered on current location; pickup via pin-drag + Places search (Medellín-biased); dropoff same; reverse-geocoded addresses shown.
  *AC: both points settable via pin and search; addresses readable in es-CO.*
  Built: `RequestScreen` exists with pickup/dropoff text fields and a
  `MapPlaceholder` where the real map goes, plus a deterministic
  `fakeGeocode` so quoting works without Maps. This is a stand-in for the
  real AC, blocked on FND-6 (Google Maps keys) — no pin-drag, no Places
  search, no reverse geocoding yet. Do not check this off once FND-6 lands
  without actually replacing the text fields with the real map/search flow.

  Follow-up (2026-08-30, Android + Web keys now exist — see `01-foundations.md`
  FND-6): real map + Places search built, not just wiring. A new
  `CraneMap` (shared across every screen that needs one — see the FND-6
  note) shows pickup/dropoff pins once set. `PlacesAutocompleteField`
  (`lib/features/customer/request/places_autocomplete_field.dart`) replaces
  the plain `TextField`s: queries the backend's `/v1/places/autocomplete`
  proxy (not Google directly — an Android/iOS app-restricted key can't
  authenticate a raw REST call from Dart; see the backend's JOB-4
  follow-up note) on every keystroke (no debounce — a `Timer`-based one
  risks leaving a pending timer behind in a widget test that doesn't pump
  long enough; a real production nicety left for later, not a correctness
  gap), shows a plain list of matches, and resolves a tap to real
  coordinates via `/v1/places/details/{id}`.

  `RequestState` gained `pickupLatLng`/`dropoffLatLng` (null = "no real fix
  for the current address text yet"). `fakeGeocode` is now truly the
  fallback, not the only path: `RequestBloc._pickupCoord`/`_dropoffCoord`
  prefer the real coordinate and fall back to `fakeGeocode(address)` only
  when there isn't one — typing over a selected suggestion by hand clears
  it back to that fallback (mirrors the web client's identical
  `pickupCoords`/`fakeGeocode` contract in `RequestPage.tsx`). This is the
  same design both apps converged on independently.

  Follow-up (2026-08-30): pin-drag built, fully this time. First pass only
  let an *existing* marker (one a search had already placed) be dragged —
  `CraneMap` gained `onTap` too, so tapping the map itself now places
  whichever of pickup/dropoff isn't set yet (`RequestScreen`: pickup first,
  then dropoff, then taps are a no-op — refining from there is drag-only).
  Both `RequestPickupPinMoved`/`RequestDropoffPinMoved` handle either case
  identically (place or refine, same event). AC's "both points settable via
  pin and search" is now genuinely met; "addresses readable in es-CO" is
  not, for a pin-placed point specifically — no reverse geocoding available
  (the Geocoding API isn't enabled — see the FND-6 note in
  `01-foundations.md`), so a pin shows a plain formatted coordinate instead
  of a real address, same honest choice the web client makes for its own
  un-geocoded GPS fix. Not checking this off for that reason.

  Also found and fixed a real bug while wiring this: `PlacesAutocompleteField`
  only updated its own text from typing/selecting *within* the field
  itself — a pickup set externally (a map tap, or `RequestBloc` rehydrating
  some other way) never reached the field's `TextEditingController` at all,
  leaving it blank. Now a proper controlled field: `RequestScreen` passes
  `RequestState.pickupAddress`/`dropoffAddress` in via a new `text` param,
  and `didUpdateWidget` syncs the controller when that changes from
  outside (guarded against clobbering the cursor mid-type when the change
  came from this field's own input).

  4 new `RequestBloc` tests (2 pin-drag, plus the bug fix is covered by the
  new widget test below) and 1 new widget test (tap places pickup then
  dropoff, drag refines pickup, asserting the field text itself — which is
  exactly what would have caught the controlled-field bug). Full suite
  green (398 passed).

  Tests: 3 new `RequestBloc` tests (real-coordinate quoting, typing-clears-it,
  job creation uses the real coordinate) + 1 new widget test (typing "poblado"
  surfaces the fake backend's seeded prediction, tapping it fills the field
  and shows the map's pickup marker). Full suite green (395 passed).
  **Not verified**: no live pass against the real Places/Directions backend
  proxy (which itself has no server-side Google key yet either — see
  FND-6) or a real rendered map on a device/simulator.

  Follow-up (2026-08-31, reverse geocoding — closes part of the "addresses
  readable in es-CO" gap the pin-drag follow-up above left open, and the
  matching gap flagged in `03-jobs-pricing.md`'s JOB-4 and `10-web-client.md`'s
  WEB-2): `PlacesRepository` gained `reverseGeocode(double lat, double lng)
  -> Future<String?>` (`lib/core/api/places_repository.dart`), calling the
  backend's new `GET /v1/places/geocode` proxy; `ApiPlacesRepository`
  catches every `DioException` and returns `null` rather than throwing —
  there is no error UI for this best-effort enrichment, only the
  pre-existing raw-coordinate text to fall back to (broader than
  `ApiDirectionsRepository.route`'s own 503-only catch, since a dragged pin
  already has a perfectly good fallback for *any* failure, not just a
  missing key).

  `RequestBloc` takes an optional `placesRepository` now (wired in
  `lib/app/router.dart` via `context.read<PlacesRepository>()`, same as
  every other repository). `RequestPickupPinMoved`/`RequestDropoffPinMoved`
  still emit the raw-coordinate text immediately as before — unchanged,
  since no server-side Google Maps key exists yet in this environment, so
  that's still exactly what a drag shows today — but now also kick off a
  background reverse-geocode call, feeding a resolved address back through
  two new internal events (`RequestPickupAddressResolved`/
  `RequestDropoffAddressResolved`) that upgrade the display text if (and
  only if) the pin hasn't since moved again, been retyped, or been replaced
  by a Places selection — guarded by comparing the resolved address's
  originating position against the field's current `pickupLatLng`/
  `dropoffLatLng`, the same staleness-guard shape `_quoteToken` already
  gives in-flight quotes.

  `FakePlacesRepository.reverseGeocode` returns a plausible address —
  "Cerca de `<nearest seeded fake place>`" by straight-line distance — never
  null, since there's no "no key configured" state to simulate under fakes.
  8 new tests: 3 direct (`test/core/api/fake_places_repository_test.dart`,
  new file — `FakePlacesRepository` had no unit tests of its own before
  this) and 5 `RequestBloc` tests (upgrade on resolve for both pickup and
  dropoff, a null resolution leaves the coordinate standing, a stale
  resolution for a superseded pin position is dropped, no-`PlacesRepository`
  construction never attempts it at all) against a new
  `ControllablePlacesRepository` test double (a `Completer`-backed fake,
  resolved on demand, so the staleness race can be driven deterministically
  rather than relying on a zero-delay fake's actual timing). One pre-existing
  widget test assertion updated to match: `FakePlacesRepository`'s zero test
  delay means its `reverseGeocode` resolves fast enough in
  `request_flow_widget_test.dart`'s existing drag test that the upgraded fake
  address is what ends up asserted, not the intermediate coordinate (both are
  now checked, at two different pump points). Full suite green (427 passed,
  up from 419), `flutter analyze` clean.

  Not verified, same standing gap as everywhere else in this session: no
  live call has been made against a real `google_maps_api_key` — every path
  above only ever exercises the backend's no-key 503 fallback, so a dragged
  pin still shows a raw coordinate on any actual run of this app today.

- [x] **CUS-2 — Vehicle type + quote sheet** *(deps: CUS-1, JOB-4)*
  Select moto / car / SUV (optionally pick a saved vehicle) → quote card with price (COP) + pickup ETA → confirm button.
  *AC: quote refreshes on any input change; stale quotes (>10 min) re-fetch.*
  Built: `RequestBloc` re-requests a quote on every pickup/dropoff/vehicle-type
  change (debounced only by token-based cancellation of in-flight requests,
  not by time) and CUS-6's saved-vehicle picker preselects type. Not built:
  the >10-minute staleness re-fetch — `Quote.expiresAt` exists on the model
  but nothing currently reads it to trigger an automatic re-quote.

  Follow-up: the staleness re-fetch is now built too. First had to fix a
  real gap the check above found: the real backend's `QuoteResponse`
  (`backend/app/schemas/job.py`) only ever returns a relative
  `expires_in_seconds` (default 600s, `QUOTE_TTL_SECONDS`), never an
  absolute `expires_at` -- so `Quote.fromJson` alone left `expiresAt` null
  against the real API every time; only `FakeJobsRepository`'s seed ever
  set it directly. `ApiJobsRepository.requestQuote` now converts the
  relative TTL into an absolute timestamp at the moment the quote arrives,
  so both backends populate it consistently.

  `RequestBloc` schedules a single one-shot `Timer` per quote (rescheduled
  from scratch on every fresh quote, simpler than periodic polling) for
  `quote.expiresAt` (falling back to a 10-minute default -- matching the
  backend's own `QUOTE_TTL_SECONDS` -- for a hypothetical future
  implementation that still leaves it null) that fires
  `RequestQuoteRefreshed` automatically. Re-checked at fire time, not just
  scheduled: a no-op if the quote's already been superseded (a newer one,
  or the customer already confirmed and moved on to matching) by the time
  it actually fires. Cancelled on confirm and on `close()`. 2 new
  `RequestBloc` tests against a short-TTL test double (auto re-fetch
  fires; does not fire once matching has started) -- `ApiJobsRepository`
  itself has no test coverage in this codebase (no `Api*Repository` dio
  -backed implementation does; everything is verified against the fakes),
  consistent with existing convention.

- [x] **CUS-3 — Matching & assignment states** *(deps: CUS-2, DSP-2)*
  "Buscando tu grúa" progress state → assigned: driver card (name, plate, truck type, rating, photo) → no-drivers state with retry.
  *AC: all three outcomes rendered from WS events; cancel available per JOB-3 rules.*
  Built: `MatchingScreen` renders all three states (searching / assigned
  driver card / no-drivers with retry), driven live by `JobsRepository.watchJob`
  (TRK-4 WS when connected, polling fallback otherwise). `RequestMatchingAbandoned`
  now calls `JobsRepository.cancelJob` (`POST /v1/jobs/{id}/cancel`, JOB-5)
  before clearing local state — best-effort, since the backend 409s past
  its grace period and the customer leaves regardless. Verified against
  the fake (which mirrors `CUSTOMER_CANCELLABLE`).

  Correction: the driver-card half of this AC (name, plate, truck type,
  rating, photo) was actually broken against the real backend the whole
  time -- `JobRead` never populated a `driver` object at all (fixed in
  JOB-5, see `_job_read` in `backend/app/api/jobs.py`), and separately the
  backend's `TruckType` enum used `standard` where the Flutter app has
  always used `car`, so even a populated one would have failed to decode.
  Both fixed now. Still not yet verified live against a real backend end
  to end.

- [ ] **CUS-4 — Live tracking screen** *(deps: TRK-4)*
  Driver marker moving live, route polyline, status timeline (assigned → en route → arrived → loading → in transit → delivered), call-driver button, share-trip button (TRK-6 link).
  *AC: marker updates ≤5s; timeline matches backend state after app restart (rehydration).*
  Built: the non-map parts. `MatchingScreen`'s `_AssignedView` now shows a
  happy-path status timeline (steps + current-step highlight + done
  coloring for earlier steps; `cancelled`/`no_drivers` render as a failure
  banner instead of a step, mirroring `web-client`'s `StatusTimeline.tsx`),
  a call-driver button (`url_launcher`'s `tel:` scheme, shown once
  `job.driver?.phone` is set), and a share-trip button that copies
  `${Env.webBaseUrl}/t/${job.shareToken}` to the clipboard with a SnackBar
  confirmation (shown once `job.shareToken` is set — both fields were
  prepped ahead of this task). Verified against the fakes (6 new widget
  tests). Not built, hard-blocked on FND-6 (no Google Maps yet): the live
  driver marker and route polyline — `MapPlaceholder` stands in wherever
  the map would go, same as `ActiveJobScreen`.

  Follow-up: the rehydration half of the AC is built now. A new
  `ActiveJobStore` (`lib/core/storage/active_job_store.dart`, disk-backed
  via `shared_preferences` — this app's first real persistence dependency;
  everything before this stored at most process-lifetime state, per
  DRV-6's own note on why it didn't reach for one) persists just the active
  job's id, not the job itself — `RequestBloc` always re-fetches the real
  thing (`JobsRepository.getJob`) rather than trusting a cached snapshot.
  `RequestBloc` now takes an optional `activeJobStore`: on construction it
  reads the persisted id (if any), re-fetches that job, and — unless it's
  gone terminal (`completed`/`cancelled`/`no_drivers`) or the fetch fails,
  either of which just clears the stale id — feeds it through the exact
  same `RequestJobUpdated` event `watchJob`'s stream already uses, so
  `RequestScreen`'s existing `BlocListener` (pushes to `MatchingScreen` the
  moment `activeJob` goes from null to non-null) picks it up with no new
  navigation wiring needed. A single `onChange` override is the one place
  that writes to the store — persists the job id while it's non-terminal,
  clears it once it isn't (or once there's no job at all) — so none of
  `RequestBloc`'s existing handlers needed a call site added. Also cleared
  on `AuthCubit.signOut()` (a real gap this surfaced: an unscoped
  device-level id would otherwise resume one user's job for whoever signs
  in next on a shared device) — `AuthCubit` gained an optional
  `activeJobStore` for exactly that one write. 15 new `RequestBloc` tests
  (resume on construction incl. a live status update arriving after, skip +
  clear on a terminal/nonexistent job, persist-on-confirm +
  clear-on-abandon, clear-on-complete) plus 1 `AuthCubit` test
  (sign-out clears it); full suite green (391 passed, up from 385).

  Not verified: an actual app kill-and-relaunch on a device/simulator — the
  above is proven at the bloc level (a fresh `RequestBloc` instance reading
  a pre-populated store, which is what a real cold start does) but never
  driven through an actual OS-level process restart.

  Follow-up (2026-08-31): the live driver marker + route polyline are built
  now too — not blocked on FND-6 alone the way the note above assumed;
  discovered while wiring the web client's own tracking map in parallel
  that `ServerMessage.driverLocation` (`lib/core/ws/server_message.dart`)
  already parsed the backend's `driver_location` WS push correctly, it just
  had no consumer anywhere in the app. `RequestBloc` now takes an optional
  `socket` (mirrors `ActiveJobCubit`'s existing pattern, just receiving
  instead of sending): `_watch(jobId)` also subscribes to
  `socket.messages`, filters to `driver_location` events for that job, and
  feeds them into a new `RequestState.driverPosition` (cleared on abandon,
  null under fakes — no socket there). A new `_AssignedJobMap`
  (`MatchingScreen`) shows pickup/dropoff pins, that live position once one
  arrives, and a route polyline fetched once per job id from
  `DirectionsRepository` (same "don't refetch on every rebuild" reasoning
  as `ActiveJobScreen`'s `_ActiveJobMap`). "Marker updates ≤5s" depends on
  how often the backend's `broadcast_job_event`/driver-location relay
  actually pushes — not something this pass measured; the wiring itself
  updates the instant a push arrives.

  3 new `RequestBloc` tests (relay for the right job, ignore a mismatched
  job id, clear on abandon) against a real `CraneSocket` + fake WS channel
  — the fakes-only convention couldn't exercise this one, since it's
  entirely a WS-transport concern. Also hit the by-now-familiar
  `flutter_test` pitfall: a widget test reaching the assigned view mounts
  `_AssignedJobMap`, whose `initState` kicks off a route fetch — a test
  that doesn't pump a real (non-zero, non-bare) duration afterward leaves
  that fetch's timer "pending" at teardown. Fixed the one existing test
  this newly affected (`CUS-3: no-drivers state offers retry`); flagging
  the pattern here since it'll bite any *future* test reaching this state
  too. Full suite green (401 passed, up from 398).

  Still not built: reverse geocoding anywhere (a pin/GPS point always
  displays as a raw coordinate — see the CUS-1 note), and no live pass
  against a real deployed backend/device for any of this.

  Follow-up (2026-08-31): the reverse-geocoding gap above is closed for the
  one place a customer actually sets a raw coordinate on this screen —
  pin-drag, on the request screen (CUS-1). See CUS-1's own follow-up note
  below for the wiring; nothing in this screen (CUS-4) itself sets a raw
  coordinate that needed the same treatment — the live driver marker is a
  read-only position feed, never something reverse-geocoded into an
  address.

- [ ] **CUS-5 — Delivery confirmation + cash payment** *(deps: CUS-4, LED-1)*
  On `delivered`: fare summary, "paid in cash" confirmation → job `completed` → rating prompt.
  Design: «Entrega y pago en efectivo» (`docs/design/screen-references.md`)
  *AC: completion writes the ledger entry (driver commission) exactly once.*
  Built: `JobStatus.nextDriverStatus` no longer maps `delivered → completed` — the
  backend already firmly restricts `confirm-delivery` to the job's customer
  (`backend/app/services/jobs.py`), so the driver's cycle now stops at
  `delivered`. `MatchingScreen`'s assigned-driver card shows the fare
  (`finalPrice ?? quotedPrice`) and a "pagado en efectivo" button once
  `delivered`, dispatching a new `RequestDeliveryConfirmed` event that calls
  the new `JobsRepository.confirmDelivery` (real dio `POST
  /v1/jobs/{id}/confirm-delivery` + fake, both added). The existing
  `watchJob` subscription then carries the job to `completed` live, and the
  pre-existing rating-button UI (RAT-2) picks it up unchanged. Also updated
  `ActiveJobCubit`/`ActiveJobScreen` (DRV-4 side) so the driver app stays
  consistent with the new state machine — see `07-driver-app.md`. Verified
  against the fakes (60 tests). Not yet verified: that the backend's
  `confirm-delivery` actually writes the ledger entry exactly once end to
  end (LED-1 lands the ledger itself; this task only wires the client call).

  Stale-note correction (2026-08-31): the "not yet verified" claim above is
  itself stale — LED-1 (`09-ledger-commission.md`, checked off) already
  covers this exactly, with a real backend test:
  `test_confirm_delivery_is_idempotent_under_double_call`
  (`backend/tests/test_job_completion.py`) calls `confirm-delivery` twice
  and asserts `len(payments) == 1` — a real, passing, end-to-end check that
  the payment/ledger row is written exactly once even under a double call.
  Audited, not rebuilt; no code changed.

- [ ] **CUS-6 — Saved vehicles** *(deps: AUTH-2)*
  CRUD for customer vehicles (type, make, model, plate) to speed repeat requests.
  Design: «Vehículos guardados» (`docs/design/screen-references.md`)
  *AC: saved vehicle preselects type in CUS-2.*
  Backend built (not in the original backlog line item, added ahead of the Flutter
  screen so it has real data to bind to): reuses the `customer_vehicles` table JOB-1
  already created for `POST /v1/jobs`' optional `customer_vehicle_id` -- it just never
  had its own CRUD until now. `type` is the existing `VehicleType` enum
  (`app/models/job.py` -- moto/car/suv), no new enum. Endpoints, all scoped to the
  caller (404 if a vehicle exists but isn't theirs):
  - `GET /v1/me/vehicles` -> `list[VehicleRead]`, most-recently-created first.
  - `POST /v1/me/vehicles` body `{type, make?, model?, plate}` -> 201 `VehicleRead`.
  - `PATCH /v1/me/vehicles/{id}` body any subset of `{type, make, model, plate}` -> 200 `VehicleRead`.
  - `DELETE /v1/me/vehicles/{id}` -> 204.

  `VehicleRead`: `{"id": "uuid", "type": "moto"|"car"|"suv", "make": str|null, "model": str|null, "plate": str|null, "created_at": "ISO8601 datetime"}`.
  Migration 0008 added `customer_vehicles.created_at` (the table didn't have it before -- nothing needed it until this ordering requirement). 9 new tests in `tests/test_vehicles_api.py`.

  Built (Flutter): `SavedVehicle` freezed model (reuses the existing `VehicleType`
  enum/wire-mapping from `job.dart`, per the contract), `VehiclesRepository`
  (real dio + fake, matching `GET/POST /v1/me/vehicles` and
  `PATCH/DELETE /v1/me/vehicles/{id}` exactly), `SavedVehiclesCubit`, and a
  list/add/edit/delete screen reachable from the new settings screen
  (alongside AUTH-5's entry). A saved-vehicle chip picker was added to the
  request screen's quote step — selecting one dispatches the existing
  `RequestVehicleTypeChanged` event, preselecting its type (AC met). Wired
  into `AppDependencies`/`main.dart`/`test_dependencies.dart` the same way
  every other repository is. Verified against the fake (77 tests, later 88
  once DRV-6 landed). The backend's real `/v1/me/vehicles` endpoints above
  match this contract exactly (both built in parallel, independently, to
  the same spec) — `ApiVehiclesRepository` has not yet been run against a
  live server end to end, that's the one remaining gap before checking
  this off.
