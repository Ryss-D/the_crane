# 07 — Driver mobile flows (DRV) · Phase 1–2 (+3)

Flutter driver shell: go available, receive offers, execute the job.

- [ ] **DRV-1 — Driver home + availability toggle** *(deps: AUTH-5, DSP-1)*
  Map + big available/offline toggle; going available starts the location stream (TRK-5); blocked states surfaced (unverified, balance cap) with explanation.
  Design: «Inicio y disponibilidad» (`docs/design/screen-references.md`)
  *AC: toggle drives the Redis geo presence end to end.*

- [ ] **DRV-2 — Incoming offer sheet** *(deps: DSP-2, TRK-4)*
  Bottom sheet on offer (WS or FCM tap-through): pickup distance, route summary, vehicle type, fare, commission preview, countdown timer from config TTL; accept / reject.
  Design: «Oferta entrante» (`docs/design/screen-references.md`)
  *AC: timeout auto-dismisses and counts as no-response; accept navigates to the active job screen.*

- [ ] **DRV-3 — Active job screen** *(deps: JOB-6, TRK-4)*
  Status-advance button per phase (En camino → Llegué → Cargado → En ruta → Entregado), map with route, deep-link to Google Maps navigation, call-customer button, cancel (returns job to matching).
  Design: «Viaje activo» — shows vehicle/plate + pickup contact, not a rider (`docs/design/screen-references.md`)
  *AC: full happy path advances through every state; backend rejections surface clearly.*

- [ ] **DRV-4 — Cash collection + completion** *(deps: DRV-3, LED-1)*
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

- [ ] **DRV-6 — Services-per-period view** *(deps: DRV-5)* · Phase 3
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
