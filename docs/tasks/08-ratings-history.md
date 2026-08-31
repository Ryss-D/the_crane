# 08 — Ratings & history (RAT) · Phase 3

Trust signals and trip records for both roles.

- [x] **RAT-1 — Ratings model + endpoint** *(deps: JOB-5)*
  `ratings` table; `POST /v1/jobs/{id}/rating` — both directions, one per side per job, only after `completed`; updates `rating_avg` on driver profile.
  *AC: duplicate rating rejected; average recomputes correctly.*

- [x] **RAT-2 — Rating UI (both roles)** *(deps: RAT-1)*
  Post-completion star + optional comment prompt for customer and driver; skippable.
  *AC: driver's rating shows on the customer's driver card (CUS-3) from real data.*
  Note: built against the fake repositories (`USE_FAKE_BACKEND`); flips to the real `/v1/jobs/{id}/rating` endpoint via the existing Api/Fake seam once FND-1 wires real auth end to end.

- [x] **RAT-3 — Trip history screens** *(deps: JOB-5)*
  Customer and driver history lists with paging; detail view: route static-map thumbnail, fare, timestamps, rating given/received.
  Design: «Historial» (`docs/design/screen-references.md`)
  *AC: paging works on 100+ seeded jobs; static maps used (no live map cost).*

  Follow-up (2026-08-30): the detail view's map thumbnail is a real static
  `CraneMap` now (pickup/dropoff pins + the route it took, via the backend's
  `/v1/directions/route` proxy — see the FND-6 note in `01-foundations.md`),
  not `MapPlaceholder`. Fetched once per screen instance (a past job's
  route never changes), matching the AC's "no live map cost" intent —
  static markers/polyline, no ongoing position stream.

- [x] **RAT-4 — es-CO localization pass** *(deps: —)*
  All user-facing strings via l10n; es-CO primary, en fallback; COP formatting (`$ 85.000`).
  *AC: no hardcoded strings in features/; currency renders es-CO style.*
  Audited: only non-l10n literal in `lib/features/` is a numeric star-count interpolation (not translatable copy). `formatCop`/`formatKm` use `es_CO` NumberFormat.
