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

- [ ] **CUS-2 — Vehicle type + quote sheet** *(deps: CUS-1, JOB-4)*
  Select moto / car / SUV (optionally pick a saved vehicle) → quote card with price (COP) + pickup ETA → confirm button.
  *AC: quote refreshes on any input change; stale quotes (>10 min) re-fetch.*
  Built: `RequestBloc` re-requests a quote on every pickup/dropoff/vehicle-type
  change (debounced only by token-based cancellation of in-flight requests,
  not by time) and CUS-6's saved-vehicle picker preselects type. Not built:
  the >10-minute staleness re-fetch — `Quote.expiresAt` exists on the model
  but nothing currently reads it to trigger an automatic re-quote.

- [x] **CUS-3 — Matching & assignment states** *(deps: CUS-2, DSP-2)*
  "Buscando tu grúa" progress state → assigned: driver card (name, plate, truck type, rating, photo) → no-drivers state with retry.
  *AC: all three outcomes rendered from WS events; cancel available per JOB-3 rules.*
  Built: `MatchingScreen` renders all three states (searching / assigned
  driver card / no-drivers with retry), driven live by `JobsRepository.watchJob`
  (TRK-4 WS when connected, polling fallback otherwise). `RequestMatchingAbandoned`
  now calls `JobsRepository.cancelJob` (`POST /v1/jobs/{id}/cancel`, JOB-5)
  before clearing local state — best-effort, since the backend 409s past
  its grace period and the customer leaves regardless. Verified against
  the fake (which mirrors `CUSTOMER_CANCELLABLE`). Not yet verified live
  against a real backend.

- [ ] **CUS-4 — Live tracking screen** *(deps: TRK-4)*
  Driver marker moving live, route polyline, status timeline (assigned → en route → arrived → loading → in transit → delivered), call-driver button, share-trip button (TRK-6 link).
  *AC: marker updates ≤5s; timeline matches backend state after app restart (rehydration).*

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
