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

- [ ] **DRV-6 — Services-per-period view** *(deps: DRV-5)* · Phase 3
  Period selector (Today / Week / Month / Custom range) over completed services: count, chart, and list for the selected range.
  Design: «Servicios por período» (`docs/design/screen-references.md`)
  *AC: range selector updates count, chart, and list together; custom range persists on reopen.*
