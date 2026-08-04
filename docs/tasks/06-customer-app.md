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
  *AC: completion writes the ledger entry (driver commission) exactly once.*

- [ ] **CUS-6 — Saved vehicles** *(deps: AUTH-2)*
  CRUD for customer vehicles (type, make, model, plate) to speed repeat requests.
  *AC: saved vehicle preselects type in CUS-2.*
