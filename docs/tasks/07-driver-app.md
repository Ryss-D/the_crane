# 07 — Driver mobile flows (DRV) · Phase 1–2 (+3)

Flutter driver shell: go available, receive offers, execute the job.

- [ ] **DRV-1 — Driver home + availability toggle** *(deps: AUTH-5, DSP-1)*
  Map + big available/offline toggle; going available starts the location stream (TRK-5); blocked states surfaced (unverified, balance cap) with explanation.
  Design: «Inicio y disponibilidad» (`docs/design/screen-references.md`)
  *AC: toggle drives the Redis geo presence end to end.*
  Built: `DriverHomeScreen`/`DriverHomeCubit` toggle available/offline and
  show a blocked banner when `!profile.verified`. Fixed a real gap found
  while auditing this against what backend now expects:
  `DriversRepository.setStatus` never sent `lat`/`lng`, but the backend's
  `DriverStatusUpdate` requires both when going `available` (422
  otherwise) — this only ever worked against the fake. `LocationSource`
  gained a one-shot `getCurrentPosition()`; the cubit grabs a fix before
  calling `setStatus` when going available (skips it if permission was
  denied, matching the AC's toggle-drives-the-Redis-geo-presence intent).
  Verified against the fake (a dedicated test asserts the fix is actually
  sent).

  Also fixed a real crash risk found along the way: Flutter's `DriverStatus`
  enum was missing `blocked` (ADM-2's admin hold) entirely — any driver
  profile response with that status would have thrown on enum decode, since
  nothing in dev/fake mode ever produces it. Added it, fixed the two
  resulting non-exhaustive-switch compile errors, and gave the blocked
  banner a `DriverBlockReason` (`unverified`/`adminBlocked`) so it shows the
  right message for each — partial progress on the AC's "blocked states
  surfaced ... with explanation."

  Closed the remaining gap this note used to flag: the settlement
  balance-cap rejection (403 on `PATCH /v1/drivers/me/status`, detail
  `"Balance owed to the platform exceeds the allowed cap"` —
  `backend/app/api/drivers.py`) is a third, distinct block reason that
  only shows up as a failed toggle attempt rather than a stored
  `DriverProfile` field. `toggleAvailability` now catches `DioException`,
  matches the detail string, and stores it in a new
  `DriverHomeState.lastToggleFailureReason` (cleared the moment the next
  toggle attempt starts) — `blockReason` checks it ahead of the two
  profile-derived reasons. Added `DriverBlockReason.balanceCap`,
  `blockedBannerBalanceCap` (both arb files), and a settable
  `FakeDriversRepository.rejectNextAvailableWithBalanceCap` flag so
  fake-mode tests can trigger the real 403 shape without replicating the
  balance calculation. Verified against the fakes (4 new tests: 3 cubit,
  1 widget). Still unchecked: no live device/backend pass has happened for
  any of DRV-1, so "toggle drives the Redis geo presence end to end" (the
  formal AC) remains unverified beyond the fakes.

  Follow-up (2026-08-30): `DriverHomeScreen`'s map area is a real `CraneMap`
  now, not `MapPlaceholder` — see the FND-6 note in `01-foundations.md`.
  Centered on Medellín only; no live self-position marker (`DriverHomeState`
  has no position field to feed one — a separate, small follow-up, not
  attempted this pass).

  Stale-note correction (2026-08-31): the self-position marker flagged
  above as a follow-up is already built — `DriverHomeState.selfPosition`
  exists and `DriverHomeScreen`'s map renders a `CraneMapMarker`
  (`role: CraneMapMarkerRole.self`) whenever it's set. It's a one-shot fix
  taken the moment the driver last went available, deliberately not a
  continuous live stream (see `toggleAvailability`'s own doc comment on
  why one doesn't run just for being available — that's TRK-5's
  background-location stream, a separate concern). Audited, not rebuilt;
  no code changed here.

- [ ] **DRV-2 — Incoming offer sheet** *(deps: DSP-2, TRK-4)*
  Bottom sheet on offer (WS or FCM tap-through): pickup distance, route summary, vehicle type, fare, commission preview, countdown timer from config TTL; accept / reject.
  Design: «Oferta entrante» (`docs/design/screen-references.md`)
  *AC: timeout auto-dismisses and counts as no-response; accept navigates to the active job screen.*
  Backend built (not in the original backlog line item, added so the offer sheet has
  real numbers to bind to instead of client-side approximations): the WS `job_offer`
  push (`JobOfferEvent`, `backend/app/schemas/job.py`) gained two fields --
  `pickup_distance_km: float | None` and `commission_amount: int | None` (both new,
  alongside the pre-existing `type`/`job_id`/`offer_id`/`vehicle_type`/`pickup`/
  `dropoff`/`quoted_price`/`expires_in_seconds`).
  `pickup_distance_km` is the real haversine distance (km, rounded to 2 decimals)
  from the offered driver's live position -- looked up via a new
  `dispatch.driver_geo_position(redis, vehicle_type, driver_id)` (GEOPOS against
  whichever geo bucket DSP-1's `add_driver_to_geo` put them in) -- to
  `job.pickup_lat`/`pickup_lng`. `None` if the driver has no entry in that geo set
  at offer time (lapsed/never set) -- this is a best-effort enrichment, never
  something that can fail an offer. `commission_amount` is the commission that
  would accrue if this offer is accepted and the job completes at the quoted price:
  `app/services/jobs.py`'s completion-accrual helper was generalized from a private
  `_commission_from_snapshot(job)` (always read `job.final_price`) into a shared
  `commission_for_fare(job, fare)`, called here with `int(job.quoted_price)` since
  `final_price` is null until completion -- same percent-of-fare/flat logic per
  `job.config_snapshot["commission"]` either way. `None` only if `quoted_price`
  itself is unset. `GeoRedisLike`/`FakeRedis` both gained `geopos` to support the
  lookup. Tested (`backend/tests/test_dispatch.py`,
  `backend/tests/test_ws.py`): `driver_geo_position` returns real coordinates for a
  seeded geo entry and `None` for an unseeded driver id;
  `test_dispatch_offer_sends_job_offer_to_driver_ws` (full create-job -> dispatch ->
  WS flow) now asserts a real non-zero `pickup_distance_km` matching an
  independently computed haversine value plus the correct `commission_amount` for
  the seeded 15%-of-fare config; two more tests call `notify_driver_offer` directly
  to cover a driver with no geo entry (`pickup_distance_km` is `None`, commission
  still computes) and a flat-mode `config_snapshot` (exact flat amount). Full suite
  green (234 passed, up from 230). No live device/backend pass -- same caveat as
  everything else this session.
  Built (Flutter): `OfferCubit`/`OfferSheet` show
  the countdown, auto-dismiss on timeout (counted as no-response), and accept
  navigates to `ActiveJobScreen` — covered by widget tests. No FCM tap-through when
  backgrounded yet (WS-only) — see below.

  Distance/commission wiring, completed: the Flutter agent that built the item
  above ran in a worktree created before the backend's enrichment landed, so it
  correctly found the schema still bare and left the hardcoded approximation in
  place rather than guessing at field names. Wired directly afterward:
  `ServerMessageJobOffer` (`lib/core/ws/server_message.dart`) gained
  `pickupDistanceKm`/`commissionAmount`, parsed by `ServerMessage.fromWire` from
  the now-real `pickup_distance_km`/`commission_amount` wire fields (null-safe —
  both are optional on the wire), and `ApiDriversRepository._toJobOffer` reads
  them, falling back to the flat-15%-of-quoted-price/zero-distance approximation
  only when the backend's own best-effort computation came back null (no live
  geo entry, or no quoted price). Tested (`test/core/ws/server_message_test.dart`):
  both fields parse correctly when present, and both parse as null when absent so
  the fallback path stays exercised too. Full suite green (148 passed, up from
  146).

  Built instead: FCM foreground/resumed handling, previously entirely
  missing (`firebase_messaging` was only ever used for `AUTH-6`'s token
  registration — nothing listened for messages). `CraneSocket.reconnectNow()`
  forces an immediate reconnect, skipping whatever backoff delay is
  currently pending — wired from `FirebaseMessaging.onMessage` (`di.dart`,
  real-backend branch) for a foreground data push, and
  `didChangeAppLifecycleState(resumed)` (`main.dart`, via
  `WidgetsBindingObserver`) for coming back from the background, the case
  most likely to have actually left the socket stale (mobile OSes tend to
  suspend networking while backgrounded). Honesty note (now stale, see
  below): at the time this was written, the backend didn't send FCM
  pushes for job offers yet either (`realtime.py`'s own `TODO(FCM)` — no
  Firebase Admin credentials configured server-side), so the `onMessage`
  listener was inert; this only wired the client half for whenever that
  landed, deliberately payload-agnostic since no message shape existed yet
  to key off. Deliberately scoped to foreground/resumed only — a
  killed-app, lock-screen notification experience needs
  `flutter_local_notifications`, platform permission flows, and a
  background isolate entry point (`FirebaseMessaging.onBackgroundMessage`),
  none of which was attempted at the time. New tests: `CraneSocket.reconnectNow`'s
  three states (before connect, already connected, mid-backoff) against
  the existing fake WebSocket channel double.

  Stale-note correction (2026-08-31): both halves flagged above as missing
  were actually built later under **TRK-3** in `05-realtime-tracking.md`,
  which this entry was never cross-referenced against. The backend's
  `TODO(FCM)` is gone — `notify_driver_offer` (`app/services/realtime.py`)
  really does call `_push_to_user(..., {"type": "job_offer", ...})` now,
  tested end to end by `test_dispatch_offer_sends_fcm_push_to_driver`
  (`backend/tests/test_ws.py`). The killed-app/backgrounded Flutter gap is
  also closed — `flutter_local_notifications` +
  `FirebaseMessaging.onBackgroundMessage` show a real local notification
  for a `job_offer` push even with the app fully killed. Still not
  checking DRV-2 off: TRK-3's own entry is explicit that none of this has
  ever been verified on a real device/emulator, and iOS has a real (not
  just unverified) architectural gap on a killed app — see TRK-3's note.

- [ ] **DRV-3 — Active job screen** *(deps: JOB-6, TRK-4)*
  Status-advance button per phase (En camino → Llegué → Cargado → En ruta → Entregado), map with route, deep-link to Google Maps navigation, call-customer button, cancel (returns job to matching).
  Design: «Viaje activo» — shows vehicle/plate + pickup contact, not a rider (`docs/design/screen-references.md`)
  *AC: full happy path advances through every state; backend rejections surface clearly.*
  Built: the full happy path (`assigned` → … → `delivered`) advances via
  `ActiveJobCubit.advance()`, with `MapPlaceholder` standing in for FND-6.
  Also built: the `TODO(DRV-3)` this note used to flag — backend rejections
  (403 "only the assigned driver"/"completion is confirmed by the
  customer", 409 out-of-order transition) no longer get swallowed. Added
  `JobsRepository.JobStatusRejectedException`, thrown by both
  `ApiJobsRepository` (catches `DioException` on 403/409, rethrows with the
  backend's `detail`) and `FakeJobsRepository` (same type, same message
  shape, for an illegal transition) so `ActiveJobCubit` doesn't care which
  backs it. `advance()` catches it and surfaces the message via a new
  `ActiveJobState.errorMessage` field; `ActiveJobScreen` shows it as a
  SnackBar. This is an API-shape change: `ActiveJobCubit` now extends
  `Cubit<ActiveJobState>` (a `@freezed` `{job, errorMessage}` wrapper, same
  pattern as `DriverHomeState`) instead of the bare `Cubit<Job?>` it was
  before — updated every consumer (`ActiveJobScreen`,
  `DriverHomeScreen`'s offer-accepted navigation listener). Verified
  against the fakes (2 new tests: 1 cubit, 1 widget, via a shared
  `RejectingOnceJobsRepository` test double). Not built: non-rejection
  errors (e.g. network) are still swallowed silently — only the typed
  rejection surfaces; no map route or Google Maps navigation deep-link, no
  call-customer button, no driver-side cancel.

  Follow-up: navigation deep-link and driver-side cancel are now built too.
  "Navegar" launches Google Maps' cross-platform web intent
  (`maps/dir/?api=1&destination=...`) via `url_launcher` — no native Maps
  SDK/API key needed — targeting the job's current leg (pickup up through
  `arrived_pickup`, dropoff from `loading` onward). Driver cancel: added an
  `asDriver` flag to `JobsRepository.cancelJob` (a fake-only distinction —
  the real backend infers customer-vs-driver from the caller's own identity,
  never a request field) so `FakeJobsRepository` returns the job to
  `matching` instead of `cancelled`, mirroring the backend's
  `DRIVER_CANCELLABLE`/`_driver_cancel`. `ActiveJobCubit.cancel()` calls it
  and surfaces a rejection (attempted past `arrived_pickup`) the same way
  `advance()` does; `ActiveJobScreen` gained a confirm-dialog-gated cancel
  button, shown only in a driver-cancellable status.
  `ApiJobsRepository.cancelJob` now also maps 403/409 into
  `JobStatusRejectedException`, matching `updateJobStatus`'s existing
  behavior (previously it didn't map these at all).

  Still not built, and not a wiring gap this time — a real one: the
  call-customer button. Checked `backend/app/schemas/job.py`'s
  `JobRead`/`JobDriverInfo` directly: there is no customer phone number
  anywhere in a job's payload — only the *driver's* phone is ever exposed,
  to the customer, via `JobDriverSummary`. There is no symmetric "customer
  summary" on the job at all. Without a backend change adding one, there is
  no legitimate phone number for this button to call, so it isn't built
  rather than faked. Map route stays blocked on FND-6, unchanged. Not
  checking this off yet for that reason (map + call-customer are both still
  outstanding, one blocked, one a real backend gap) — everything else in
  the AC is met. New tests: `ActiveJobCubit.cancel()` success (back to
  `matching`, local state cleared) and rejection-past-`arrived_pickup`,
  against the fakes.

  Follow-up (2026-08-30): map route built. A new `_ActiveJobMap` (real
  `CraneMap` + pickup/dropoff pins + a route polyline from the backend's
  `/v1/directions/route` proxy — see the FND-6 note in `01-foundations.md`)
  replaces `MapPlaceholder`, fetching the route once per job id (not on
  every rebuild — this screen rebuilds on every status advance and every
  location-socket tick, which would otherwise spam the backend).

  Follow-up (2026-08-31): call-customer built too — closes the AC's last
  gap. Backend gained a symmetric `JobCustomerInfo` (`id`/`name`/`phone`) on
  `JobRead.customer`, populated in `_job_read` unconditionally (a job always
  has a customer, unlike `driver`) — safe: `JobRead` is only ever returned
  to the job's own customer, its assigned driver, or an admin
  (`get_job`'s `_require_view_access`), the same three parties who could
  already see this via `AdminJobListItem.customer_phone` or by being the
  customer themself, so this adds no new exposure — matches `driver`'s own
  precedent exactly rather than inventing a narrower rule. `Job`
  (`lib/core/models/job.dart`) gained a symmetric `JobCustomerSummary`;
  `ActiveJobScreen` gained a call-customer button next to "Navegar",
  mirroring the customer app's call-driver button exactly (same
  `url_launcher` `tel:` scheme, same phone-conditional guard). 2 new
  backend tests (`test_jobs_api.py`), 1 new Flutter widget test. Also fixed
  a real, unrelated widget-test regression this surfaced: the new button
  pushed `advanceStatusButton`/`navigateButton` further down
  `_ActiveJobView`'s `SingleChildScrollView`, past what `flutter_test`'s
  fixed-size test surface renders as visible — `tester.tap` on an
  off-screen target silently no-ops (no exception, the tap just lands
  nowhere), which made every multi-advance test in
  `driver_flow_widget_test.dart` fail as "stuck on `assigned`" with zero
  error surfaced. Fixed with `tester.ensureVisible(...)` before each
  affected tap, matching the pattern this same file already used for
  `backToHomeButton`/`cancelJobButton`/`rateTripButton`. Full suite green
  (402 passed, backend 337 passed). This AC is now fully met at the
  fakes/mocked-backend level; not yet verified against a live device or
  real backend deploy.

- [x] **DRV-4 — Cash collection + completion** *(deps: DRV-3, LED-1)*
  On delivered: fare + "collected in cash" confirmation; shows commission accrued for this job and new running balance.
  Design: «Cobro en efectivo» (`docs/design/screen-references.md`)
  *AC: balance shown matches ledger after completion.*
  Built (started as part of CUS-5's JobStatus fix, finished after DRV-5):
  the driver has no "collected in cash" button at all now — only the
  customer can complete a job (CUS-5's `confirm-delivery`), so
  `ActiveJobScreen` shows an informational "Esperando que el cliente
  confirme el pago en efectivo" message once `delivered` instead.
  `ActiveJobCubit` subscribes to `JobsRepository.watchJob` (mirrors
  `RequestBloc._watch`), so the screen flips to the existing "done" UI live
  once the customer confirms, with no driver action needed. Once done, a
  new section fetches `DriversRepository.balance()` (DRV-5) and shows both
  the commission earned on this job and the fresh running balance — the
  per-job commission itself is approximated client-side at a flat 15%
  (same approximation already used for the DSP-2 offer preview) since the
  backend doesn't return a real per-job commission figure yet; a TODO in
  `active_job_screen.dart` calls this out. Verified against the fakes (84
  tests, including a dedicated assertion that both amounts render after a
  live completion).
  Now done end-to-end: `JobRead` (`backend/app/schemas/job.py`) has a
  `driver_commission: int | None` field — null until the job is `completed`,
  otherwise the real LED-1 `DriverLedgerEntry.commission` for that job
  (populated in `_job_read`, `backend/app/api/jobs.py`, one extra query,
  same skip-if-not-applicable pattern as the existing `driver` field). Every
  job-returning endpoint (including `GET /v1/jobs/{id}` and the
  confirm-delivery response) serves it. `Job` (`lib/core/models/job.dart`)
  gained `driverCommission`; `active_job_screen.dart` now shows it once a
  job is completed, falling back to the flat-15% approximation only if the
  backend value is null (kept as a safety net, not because it's still
  needed in the real-backend path). `FakeJobsRepository` seeds the same
  field on completion so the fake-backend demo path renders realistic data
  too. AC verified against the fakes and against backend tests
  (`tests/test_job_completion.py`); not verified against a live device.

- [ ] **DRV-5 — Earnings & balance screen** *(deps: LED-1)*
  Completed jobs list, cash totals per day/week, commission balance owed, settlement instructions (static text until PAY-* lands).
  Design: «Ganancias y saldo» (`docs/design/screen-references.md`)
  *AC: numbers reconcile with `driver_ledger` for a seeded dataset.*
  Backend built (not in the original backlog line item, added ahead of the Flutter
  screen so it has real data to bind to): `GET /v1/drivers/me/balance`, auth'd as the
  calling driver (404 if no driver_profile yet). Response:
  ```json
  {
    "owed_cents": 10000,
    "balance_cap_cents": 50000,
    "recent_settlements": [
      {"id": "uuid-string", "amount_cents": 5000, "settled_at": "2026-08-05T12:00:00Z", "note": "partial settlement"}
    ]
  }
  ```
  `owed_cents` is `driver_owed_balance()` (app/services/ledger.py); `balance_cap_cents`
  is `null` when `settlement.balance_cap` is disabled in config. `recent_settlements`
  is every `payout` driver_ledger row for this driver (newest first, capped at 20) --
  the same row shape both the per-driver admin settle (LED-4) and the fleet settle
  (FLT-2) write, so a fleet-level settlement shows up here too. Does NOT cover the
  completed-jobs list or day/week cash totals DRV-5's full AC asks for -- those read
  from `jobs`/`driver_ledger` `earning` rows directly and are still open for whoever
  builds the Flutter screen (or a follow-up backend task) to wire up.

  Built (Flutter): `DriverBalance`/`Settlement` freezed models matching
  `GET /v1/drivers/me/balance` exactly, a `DriversRepository.balance()`
  method (real dio + fake — the fake computes owed commission from
  completed jobs the seed driver worked, mirroring the backend's
  `driver_owed_balance` formula, minus one seeded settlement), a
  `DriverBalanceCubit`, and a new `EarningsScreen` reachable from a wallet
  icon on the driver home app bar: current owed balance (formatted COP),
  the balance cap when the platform has one configured, and a list of
  recent settlements. NOTE on units, resolved: despite the `_cents` field
  names above, every other money value in this codebase (and the backend's
  own `Numeric(12, 0)` ledger columns, which have no subunit) is a plain
  integer COP amount — this was built treating those fields as plain COP
  too (formatted directly via `formatCop`, not divided by 100), consistent
  with the rest of the app. Not yet built: the "completed jobs list" and
  "cash totals per day/week" part of this AC's grouping — that's DRV-6's
  services-per-period view, built separately. Verified against the fake
  (84 tests, later 88 once DRV-6 landed).

  Follow-up (2026-08-31): "settlement instructions (static text until
  PAY-* lands)" is real now, not static text — PAY-3's `POST
  /v1/drivers/me/settle` (already built and tested) is wired up.
  `DriversRepository` gained `settleBalance({amountCop, method})` (real dio
  + fake — the fake validates the same rules the backend does (amount > 0,
  amount <= owed, something actually owed) but deliberately never touches
  `_settlements`, since a real settlement only applies once Wompi's webhook
  reports the payment approved; optimistically decrementing it here would
  be dishonest). Throws a new `SettlementRejectedException` for every
  backend rejection (422/409/503), same convention as
  `JobStatusRejectedException`.

  `EarningsScreen` gained a "Liquidar saldo" button (shown only when
  something is owed) opening a dialog to pick an amount (prefilled with
  the full owed balance) and a method (Nequi/PSE/tarjeta). `DriverBalanceCubit`
  drives it (`settle`/`clearSettlementResult`), and the screen reacts via a
  `BlocListener`: Nequi shows a "check your app" message, PSE/card opens
  the returned `async_payment_url` via `url_launcher`. The shown balance
  itself is deliberately never updated optimistically after a request —
  same "only a real webhook moves it" honesty as the fake.

  6 new repository tests, 4 new widget tests (button hidden at zero
  balance, Nequi happy path, over-balance disables submit, the 503
  "not available yet" path). Full Flutter suite green. **Not checked
  off**: DRV-5's full AC (completed-jobs list / day-week totals, covered by
  DRV-6, plus this settlement piece) still has no live pass against a real
  Wompi account — none exists yet (see the PAY-1..5 note in
  `12-payments-wompi.md`).

- [x] **DRV-6 — Services-per-period view** *(deps: DRV-5)* · Phase 3
  Period selector (Today / Week / Month / Custom range) over completed services: count, chart, and list for the selected range.
  Design: «Servicios por período» (`docs/design/screen-references.md`)
  *AC: range selector updates count, chart, and list together; custom range persists on reopen.*
  Built (partial): a client-side grouping over the existing
  `JobsRepository.listHistory` data (no new backend endpoint) — a
  `ServicesPeriodCubit` pages through the driver's full history, keeps only
  `completed` jobs, and buckets them by calendar day (local time), summing
  a count, total cash fare, and total commission (same flat-15%
  approximation used elsewhere) per day. A new `ServicesPeriodScreen`,
  reachable from a calendar icon on DRV-5's earnings screen, lists those
  daily buckets newest-first. Day was picked over week/month/custom-range
  because grouping by day needs nothing beyond `Job.completedAt`; the full
  Today/Week/Month/custom-range selector and chart from the AC are NOT
  built — this is a straight daily breakdown only. Verified against the
  fake (88 tests).

  Follow-up: the full selector is built now too. `ServicesPeriodCubit`
  gained a `ServicesPeriodFilter` (today/week/month/custom); switching it
  re-slices the same already-loaded job list in memory rather than
  re-fetching (`listHistory` has no date-range filtering to push this down
  to anyway). `week`/`month` are rolling windows anchored on today (last 7
  days / current calendar month) rather than locale-anchored calendar
  weeks — the same "nothing this client-side pass can assume safely"
  reasoning that originally picked day-grouping over week-grouping applies
  to a Monday-vs-Sunday week start too, so this sidesteps it the same way.
  `custom` uses Flutter's built-in `showDateRangePicker` (no new
  dependency). `ServicesPeriodScreen` gained a `SegmentedButton` selector, a
  totals card (count/fare/commission for whichever filter is active --
  count, chart, and list all derive from the exact same filtered
  `periods` list, so they can't drift apart), and a proportional-width bar
  behind each day's fare as the AC's "chart" -- this app has no charting
  package, and a bar-list is the "reasonable substitute" called out for
  exactly this case rather than adding one.

  Custom-range persistence: this app has no persistence layer
  (shared_preferences or similar) at all yet, and `ServicesPeriodCubit` is
  recreated on every visit to the screen (see the `services` route in
  `lib/app/router.dart`), so a plain instance field wouldn't survive
  leaving and reopening it. Built with static in-memory module state
  instead (documented on the static fields themselves) -- honestly, this
  is process-lifetime persistence, not disk persistence: it survives
  navigating away and back within the same running app, not a full app
  restart. That's the most honest thing buildable without introducing a
  real persistence dependency.

  New tests: filter-selection totals (today/week), custom-range exact
  membership, `maxDayFare` (backs the bar widths), and the "remembered
  across a fresh cubit instance" persistence behavior, against a small
  seeded-history test double (the existing fake always completes jobs at
  `DateTime.now()`, with no way to backdate one through its public API) --
  plus a widget-level test that switching the selector keeps the shown
  count in sync. Full suite green (146 passing, up from 142).
