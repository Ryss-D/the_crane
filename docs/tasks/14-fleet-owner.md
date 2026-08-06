# 14 — Fleet owner (FLT) · Phase 6

New role: owners of multiple grúas who assign drivers to trucks and settle one consolidated commission balance. Backend foundations first (FLT-1/2), then the owner-facing screens (FLT-3/4/5 — the frames in `docs/design/screen-references.md`).

- [x] **FLT-1 — Fleet owner role + fleets model** *(deps: AUTH-1, AUTH-5)*
  Add `fleet_owner` to the role enum (already present since AUTH-1) and a `fleets` table (owner user_id); wire the pre-existing `trucks.fleet_id` (nullable since AUTH-5) to it. A truck can exist without a driver; independent drivers keep working with no fleet.
  *AC: fleet CRUD works; dispatch capacity filtering (already reading `trucks`) is unaffected for independent drivers.*
  Built: `fleets` table (migration 0007) + FK/index finally added on the pre-existing `trucks.fleet_id`. `POST /v1/fleets/me` creates the caller's fleet and flips role -> fleet_owner (409 if they already own one, mirrors AUTH-5's register flow); `GET /v1/fleets/me` returns it with its trucks; `POST`/`DELETE /v1/fleets/me/trucks/{truck_id}` attach/detach (409 if the truck already belongs to a fleet, 404 otherwise). Judgment call: real driver-consent for joining a fleet is FLT-4 (not built yet, it's a later Flutter-facing task with an invite flow) — for now any truck with `fleet_id is None` can be claimed by any fleet owner, same "unclaimed resource" gate as AUTH-5's plate uniqueness. `app/services/dispatch.py` never reads `fleet_id`, so independent-driver dispatch is untouched (verified: existing dispatch tests still pass). 8 new tests (`tests/test_fleets_api.py` + a model roundtrip case), full suite green (191 passed).

- [x] **FLT-2 — Fleet ledger rollup + consolidated settlement** *(deps: FLT-1, LED-1, LED-4)*
  Ledger entries gain fleet attribution via the truck; consolidated balance per fleet owner; settle endpoint accepts a fleet-level payment that clears the constituent driver balances; balance-cap gating (LED-2) evaluates at fleet level for fleet drivers.
  *AC: fleet balance equals sum of member driver balances; one fleet settlement unblocks all capped members.*
  Built: `app/services/ledger.py` gains `fleet_member_driver_ids`/`fleet_member_balances`/`fleet_owed_balance` (a driver's fleet is found via their truck, not a stored column — no ledger schema change needed) plus an `apportion()` helper (largest-remainder rounding so per-driver shares always sum exactly to the settlement amount). `GET /v1/fleets/me/balance` (fleet owner) and `GET /v1/admin/fleets/{fleet_id}/balance` (admin) return the rollup + per-driver breakdown; `POST /v1/admin/fleets/{fleet_id}/settle` records ONE payment apportioned across every member driver as ordinary `payout` driver_ledger rows (409 if the fleet has no drivers, 422 on non-positive amount). `PATCH /v1/drivers/me/status`'s balance-cap gate now checks `fleet_owed_balance` instead of `driver_owed_balance` when the driver's truck has a `fleet_id`, independent drivers unaffected. 7 new tests in `tests/test_fleet_ledger.py` cover the rollup-equals-sum AC, apportionment/rounding, and the "one settlement unblocks every capped member" AC directly; full suite green (198 passed).

- [x] **FLT-3 — "Mi flota" screen** *(deps: AUTH-4, FLT-1)*
  Fleet owner shell in the Flutter app: per-truck status at a glance (available / on job / unassigned / offline), tap-through to truck detail.
  Design: «Mi flota» (`docs/design/screen-references.md`)
  *AC: statuses reflect live dispatch state for a seeded fleet.*
  Backend built (not in the original backlog line item, added ahead of the Flutter
  screen so it has real data to bind to): `TruckRead` gains `driver_status`/
  `driver_name` (both `null` by default; only `GET /v1/fleets/me` populates them,
  via one batched query each across the fleet -- neither lives on `Truck` itself).
  Tested (`test_fleet_trucks_show_live_driver_status_and_name`), full suite green
  (217 passed).

  Flutter half in progress: `Truck` gained the same `driverStatus`/`driverName`
  fields, plus `Fleet`/`FleetBalance` models and a `FleetRepository` (interface +
  `ApiFleetRepository` + `FakeFleetRepository`, same seam every other repository
  uses). The onboarding half also landed -- a "Crear mi flota" entry in
  `SettingsScreen` -> `BecomeFleetOwnerScreen` (fleet name only) ->
  `FleetRepository.createFleet` -> `AuthCubit.refreshUser()`, and `routerRedirect`
  now sends `fleet_owner` to a new `/fleet` `ShellRoute` (`FleetCubit` +
  `FleetHomeScreen`) instead of the customer/driver shells. `FleetHomeScreen`
  lists every truck with its plate, driver name, and status at a glance
  (available/on job/offline/unassigned -- `TruckFleetStatusLabel` in
  `labels.dart`). Tapping a row now pushes `/fleet/trucks/:truckId` ->
  `FleetTruckDetailScreen` (plate, type, capacity, driver name/status),
  reading straight from `FleetCubit`'s already-loaded state rather than a
  second fetch, so FLT-4's attach/detach will show up immediately. Checked
  off: the AC ("statuses reflect live dispatch state for a seeded fleet")
  and the "tap-through to truck detail" requirement are both covered by the
  seeded-fleet widget tests. Full suite green (108 passed).

- [ ] **FLT-4 — Assign driver to truck** *(deps: FLT-3)*
  Link a verified driver to an unassigned truck, or invite a new driver (phone invite → signup lands pre-linked); unassign flow.
  Design: «Asignar conductor a una grúa» (`docs/design/screen-references.md`)
  *AC: assigned driver's offers/dispatch use the truck's capacity; a truck has at most one active driver.*
  Backend note: only the "link to an already-unassigned truck" half is buildable
  today, via FLT-1's `POST/DELETE /v1/fleets/me/trucks/{truck_id}` (per FLT-1's own
  judgment-call note: any unclaimed truck can be attached, no consent flow yet).
  The "invite a new driver via phone, signup lands pre-linked" half needs a new
  backend invite/token mechanism that doesn't exist -- out of scope until someone
  builds it.

- [ ] **FLT-5 — Fleet earnings screen** *(deps: FLT-2)*
  Commission accrued per truck, consolidated balance owed, settlement action (cash instructions; Wompi via PAY-3 pattern later).
  Design: «Ganancias de la flota» (`docs/design/screen-references.md`)
  *AC: per-truck numbers reconcile with the ledger; consolidated total matches FLT-2.*
