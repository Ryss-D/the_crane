# 06 — Customer mobile flows (CUS) · Phase 1–2

Flutter customer shell: request a tow, follow it live, confirm delivery.

- [ ] **CUS-1 — Request screen: map + location pickers** *(deps: AUTH-4, FND-6)*
  Map centered on current location; pickup via pin-drag + Places search (Medellín-biased); dropoff same; reverse-geocoded addresses shown.
  *AC: both points settable via pin and search; addresses readable in es-CO.*

- [ ] **CUS-2 — Vehicle type + quote sheet** *(deps: CUS-1, JOB-4)*
  Select moto / car / SUV (optionally pick a saved vehicle) → quote card with price (COP) + pickup ETA → confirm button.
  *AC: quote refreshes on any input change; stale quotes (>10 min) re-fetch.*

- [ ] **CUS-3 — Matching & assignment states** *(deps: CUS-2, DSP-2)*
  "Buscando tu grúa" progress state → assigned: driver card (name, plate, truck type, rating, photo) → no-drivers state with retry.
  *AC: all three outcomes rendered from WS events; cancel available per JOB-3 rules.*

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
