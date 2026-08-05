# The Crane — Product & Technical Plan

Uber-style dispatch app for grúas (tow trucks) that haul motorcycles and cars.

**Stack decisions (locked):**
- **Frontend (mobile):** Flutter — single app, role switch (customer / driver) after login
- **Frontend (web):** React — customer-only web app for users without the app installed (request + track a grúa from the browser)
- **Backend:** FastAPI (Python) + PostgreSQL/PostGIS
- **Firebase:** Auth (identity) + Cloud Messaging (push). Backend verifies Firebase ID tokens.
- **Maps:** Google Maps (google_maps_flutter, Places, Directions)
- **Payments:** Cash for MVP; Wompi (cards/PSE/Nequi) in a later phase
- **Market:** Medellín, Colombia — COP currency, es-CO primary locale, +57 phone OTP, Places biased to the Valle de Aburrá
- **Monetization:** platform commission charged to the driver per completed service (tracked in the driver ledger from day one)

---

## 1. System architecture

```
┌─────────────────────────┐   ┌─────────────────────────┐
│      Flutter app        │   │     React web app        │
│  (customer + driver UI) │   │ (customer request/track, │
└───┬───────┬─────────┬───┘   │  no install needed)      │
    │       │         │       └───────────┬──────────────┘
    │  Firebase Auth  │ Google Maps /     │  same REST + WS,
    │  (ID tokens)    │ Places / Directions  Firebase Auth (web)
    │       │         │                   │
    ▼       │         ▼◄──────────────────┘
┌─────────────────────────┐        ┌──────────────┐
│       FastAPI            │◄──────►│  PostgreSQL  │
│  REST + WebSockets       │        │  + PostGIS   │
│  - verifies Firebase JWT │        └──────────────┘
│  - dispatch/matching     │        ┌──────────────┐
│  - pricing               │───────►│  Redis        │
│  - job state machine     │        │ (live driver  │
└───────────┬─────────────┘        │  locations,   │
            │                       │  pub/sub)     │
            ▼                       └──────────────┘
      Firebase FCM
   (push: job offers,
    status updates)
```

**Why this split:**
- Firebase Auth removes password/OTP handling from the backend; FastAPI just verifies the ID token (via `firebase-admin`) in a dependency.
- PostGIS gives real geo-queries (nearest available driver within radius, ordered by distance) that Firestore can't do well.
- WebSockets (FastAPI native) carry live driver location and job status to the app; FCM covers the app-in-background case (job offers to drivers, status changes to customers).
- Redis holds ephemeral driver locations (updated every ~5s) and pub/sub between API workers; Postgres only stores location snapshots on job events.

---

## 2. Backend (FastAPI)

### 2.1 Project layout

```
backend/
├── app/
│   ├── main.py                 # FastAPI app, routers, lifespan
│   ├── core/
│   │   ├── config.py           # pydantic-settings (env vars)
│   │   ├── security.py         # Firebase token verification dependency
│   │   └── database.py         # async SQLAlchemy engine/session
│   ├── models/                 # SQLAlchemy models
│   │   ├── user.py
│   │   ├── driver.py
│   │   ├── vehicle.py
│   │   ├── job.py
│   │   └── rating.py
│   ├── schemas/                # Pydantic request/response schemas
│   ├── api/
│   │   ├── auth.py             # POST /auth/sync (create profile after Firebase signup)
│   │   ├── users.py
│   │   ├── drivers.py          # availability, location, documents
│   │   ├── jobs.py             # request, quote, accept, status transitions
│   │   └── ws.py               # WebSocket endpoints
│   ├── services/
│   │   ├── dispatch.py         # matching algorithm
│   │   ├── pricing.py          # fare calculation
│   │   ├── jobs.py             # state machine + side effects
│   │   └── notifications.py    # FCM sends
│   └── workers/                # (later) background tasks — offer timeouts, cleanup
├── alembic/                    # migrations
├── tests/
├── pyproject.toml              # uv or poetry; ruff + pytest
└── Dockerfile
```

### 2.2 Data model (core tables)

- **users** — `id (uuid)`, `firebase_uid (unique)`, `role (customer|driver|admin)`, `name`, `phone`, `email`, `fcm_token`, `created_at`
- **driver_profiles** — `user_id FK`, `status (offline|available|on_job)`, `verified (bool)`, `license_url`, `truck_plate`, `truck_type (moto_only|car|flatbed)`, `capacity (moto|car|both)`, `rating_avg`
- **customer_vehicles** — `user_id FK`, `type (moto|car|suv)`, `make`, `model`, `plate` (optional, speeds up repeat requests)
- **jobs** — `id`, `customer_id`, `driver_id (nullable)`, `vehicle_type`, `status`, `pickup geom(Point,4326)`, `pickup_address`, `dropoff geom(Point,4326)`, `dropoff_address`, `distance_km`, `quoted_price`, `final_price`, `payment_method (cash)`, timestamps per transition (`requested_at`, `assigned_at`, `picked_up_at`, `completed_at`, `cancelled_at`), `cancel_reason`
- **job_offers** — `job_id`, `driver_id`, `offered_at`, `responded_at`, `response (accepted|rejected|timeout)` — audit trail of the dispatch fan-out
- **ratings** — `job_id`, `from_user`, `to_user`, `stars`, `comment`
- **driver_location_snapshots** — location at each job transition (dispute/audit trail); live locations stay in Redis only
- **platform_config** — versioned key/value config edited from the super admin panel, cached in Redis, never requires a deploy:
  - pricing: `base_fare`, `per_km`, `min_fare` per vehicle type
  - commission: `mode (percent|flat)`, `rate`/`amount` per vehicle type
  - settlement: `balance_cap` (COP owed before new offers are blocked, nullable = never block), `settlement_period`
  - dispatch: offer TTL seconds, search radius km, radius-widening steps
  - each change stores `changed_by` + previous value (audit log); jobs snapshot the config values they were priced with, so a rate change never rewrites history

### 2.3 Job state machine

```
requested ──► matching ──► assigned ──► en_route_pickup ──► arrived_pickup
                 │             │                                   │
                 ▼             ▼                                   ▼
             no_drivers    cancelled                            loading ──► in_transit ──► delivered ──► completed
                                                                                              (customer confirms + pays cash)
```

- Transitions live in one service function with an allowed-transitions map; every transition is timestamped, persisted, broadcast on the job's WebSocket channel, and pushed via FCM.
- Cancellation rules: customer can cancel free until `assigned` + grace period; driver cancellation returns job to `matching`.

### 2.4 Dispatch / matching (MVP)

1. Job created → status `matching`.
2. Query Redis geo-set for available drivers within N km whose `capacity` fits the vehicle type; order by distance.
3. Offer to the nearest driver (FCM + WebSocket) with a 30s TTL; on reject/timeout, offer to the next. Record each offer in `job_offers`.
4. Exhausted list → widen radius once, then mark `no_drivers` and notify the customer.

Sequential-offer is deliberately simple; broadcast-to-many can come later.

### 2.5 Pricing (MVP)

`fare = base(vehicle_type) + per_km(vehicle_type) × road_distance_km`, minimum fare per type, in COP. Distance from Google Directions at quote time. Store the quote on the job; final price = quote (no surge in MVP). Config table so prices are editable without deploys.

**Platform commission (driver service fee):** on every `completed` job, a commission is written to `driver_ledger` as a debit against the driver — percent-of-fare or flat COP fee, per vehicle type, read from `platform_config` at completion time (and snapshotted onto the job). With cash jobs the driver keeps the fare and **owes** the platform the commission; the driver home screen shows a running balance. Commission mode/rate, the balance cap that blocks new offers, and the settlement period are all **super-admin-configurable at runtime** — no deploys, no code changes.

### 2.6 API surface (v1)

```
POST   /v1/auth/sync                 # after Firebase signup — create/fetch profile
GET    /v1/me
PATCH  /v1/me                        # profile, fcm_token
POST   /v1/drivers/me/documents      # license, plate, truck info
PATCH  /v1/drivers/me/status         # available / offline
PUT    /v1/drivers/me/location       # (fallback REST; primary is WS)
POST   /v1/jobs/quote                # pickup, dropoff, vehicle_type → price + ETA
POST   /v1/jobs                      # create request
GET    /v1/jobs/{id}
GET    /v1/jobs?role=customer|driver # history
POST   /v1/jobs/{id}/accept          # driver
POST   /v1/jobs/{id}/status          # driver transitions
POST   /v1/jobs/{id}/cancel
POST   /v1/jobs/{id}/rating
WS     /v1/ws                        # authed socket: driver location up; job events down

# super admin (role=admin, separate router + permission dependency)
GET    /v1/admin/config              # full platform_config with audit history
PUT    /v1/admin/config/{key}        # update pricing/commission/settlement/dispatch params
GET    /v1/admin/drivers             # list + filter (pending verification, blocked, balance)
POST   /v1/admin/drivers/{id}/verify
POST   /v1/admin/drivers/{id}/block
GET    /v1/admin/jobs                # live + historical, filters
GET    /v1/admin/ledger              # balances per driver, settlement marking
POST   /v1/admin/ledger/{driver_id}/settle   # record a balance payment/adjustment
```

Auth: `Authorization: Bearer <firebase_id_token>` on every call; FastAPI dependency resolves it to a `users` row.

### 2.7 Infra / DevOps

- Docker Compose for local dev (api + postgres/postgis + redis).
- Alembic migrations from day one.
- Deploy target (MVP): single VM or Railway/Fly.io/Cloud Run + managed Postgres (Neon/Supabase-as-Postgres/Cloud SQL).
- CI: ruff + pytest on PR (GitHub Actions).

---

## 3. Frontend (Flutter)

### 3.1 Packages

| Concern | Package |
|---|---|
| State management | `flutter_bloc` (Blocs/Cubits, sealed freezed states; DI via RepositoryProvider) |
| Routing | `go_router` (auth + role guards) |
| HTTP | `dio` (interceptor injects Firebase ID token) |
| WebSocket | `web_socket_channel` |
| Auth | `firebase_auth` (phone OTP primary, email fallback) |
| Push | `firebase_messaging` + `flutter_local_notifications` |
| Maps | `google_maps_flutter`, `geolocator`, `geocoding` |
| Places autocomplete | Places API via dio (avoids heavyweight plugin) |
| Models | `freezed` + `json_serializable` |
| Env | `--dart-define-from-file` per flavor |

### 3.2 App structure (feature-first)

```
lib/
├── main.dart
├── app/
│   ├── router.dart              # go_router: auth guard, role-based start route
│   ├── theme.dart
│   └── providers.dart           # dio, ws client, firebase instances
├── core/
│   ├── api/                     # dio client, interceptors, error mapping
│   ├── ws/                      # socket lifecycle, reconnect, event stream
│   └── models/                  # Job, User, DriverProfile, LatLng ext (freezed)
├── features/
│   ├── auth/                    # phone OTP flow, profile completion, role pick
│   ├── customer/
│   │   ├── request/             # map, pickup/dropoff pickers, vehicle type, quote
│   │   ├── tracking/            # live job screen: driver marker, status timeline
│   │   └── history/
│   ├── driver/
│   │   ├── home/                # availability toggle, incoming-offer sheet (30s timer)
│   │   ├── job/                 # active job: navigate btn, status transition buttons
│   │   └── earnings/            # completed jobs, cash totals, commission balance owed
│   └── shared/
│       ├── rating/
│       └── profile/
└── l10n/                        # es (primary) + en
```

### 3.3 Key flows

**Customer — request a tow:**
map with current location → set pickup (pin drag / Places search) → set dropoff → choose vehicle type (moto / car / SUV) → see quote + ETA → confirm → "finding your grúa" → assigned: driver card (name, plate, rating, truck photo) + live marker → status timeline through delivery → confirm delivery, pay cash → rate driver.

**Driver — work a job:**
toggle available (starts foreground location service, WS location stream every ~5s) → offer sheet appears with pickup distance, route summary, fare, 30s countdown → accept → status buttons advance the state machine (En route → Arrived → Loaded → In transit → Delivered) → deep-link to Google Maps for navigation → collect cash → done, back to available.

**Role switch:** role stored on the user profile; router sends each role to its shell. A user can register as driver from settings (uploads docs, waits for admin verification — MVP: manual flag in DB).

### 3.4 Realtime & background rules

- Foreground: WebSocket is the source of truth for job events and driver position.
- Background/killed: FCM data messages (job offer, status change) → notification; opening the app rehydrates from `GET /jobs/{id}`.
- Driver location in background: `geolocator` foreground-service mode on Android; iOS background location entitlement (justified: active job tracking).

---

## 4. React web client (no-install customer flow)

A stranded driver with a dead moto shouldn't need an App Store download. The web app covers the **customer role only** — drivers always use the Flutter app (background location and push don't work reliably enough on mobile web).

### 4.1 Stack

- **Vite + React + TypeScript** (SPA is enough — this is an authed app, not a marketing site; if SEO landing pages are wanted later, put them on a separate static site or upgrade to Next.js then)
- **State/data:** TanStack Query for REST, small Zustand store for the active-job/socket state
- **Auth:** Firebase Auth web SDK — same phone-OTP flow, same ID token, so **zero backend changes**; one shared user account across app and web
- **Maps:** `@vis.gl/react-google-maps` + Places Autocomplete (same Google billing account/keys, web-restricted key)
- **Realtime:** native `WebSocket` to the same `/v1/ws`; fallback to polling `GET /jobs/{id}` every 10s if the socket drops
- **Notifications:** none required — the tracking page is live while open; SMS fallback (Twilio or local aggregator) for "driver assigned/arrived" is the phase-2 nicety since web push on iOS Safari is unreliable
- **UI:** Tailwind, mobile-first (most users will open this on a phone browser)

### 4.2 Scope

**In:** phone OTP login → request flow (pickup auto-from-browser-geolocation, dropoff, vehicle type) → quote → confirm → live tracking page → cash/later-digital payment status → rating.
**Also in:** a **public share-track link** (`/t/{job_token}`) — read-only live map of the tow, shareable with family/insurer; token-scoped, no login. The Flutter app gets a "share trip" button that produces the same link.
**Out:** driver features, trip history beyond last job (v1), profile management.

### 4.3 Layout

```
web-client/          # note: `web/` is taken by Flutter's web build target
├── src/
│   ├── api/            # typed client (generated from FastAPI OpenAPI schema)
│   ├── auth/           # firebase web, token provider
│   ├── features/
│   │   ├── request/    # map, pickers, quote, confirm
│   │   ├── tracking/   # live job view (also powers public /t/{token})
│   │   └── rating/
│   ├── ws/             # socket hook with polling fallback
│   └── ui/
├── index.html
└── vite.config.ts
```

- **Generate the API client from FastAPI's OpenAPI spec** (`openapi-typescript` or `orval`) — the backend contract stays the single source of truth for both frontends.
- Backend addition needed: `GET /v1/track/{job_token}` + a WS/poll channel for the public share link (token minted at job creation).
- Deploy: static hosting (Cloudflare Pages / Vercel) + the existing API; CORS allowlist for the web origin.

### 4.4 Super admin panel

A separate React SPA (`admin/`, same stack and generated API client as `web-client/`) behind the `admin` role — desktop-first, internal-only, deployed on its own subdomain (`admin.…`). Sections:

- **Platform config** — the control room for everything marked configurable: pricing (base/per-km/min per vehicle type), **commission mode + rate per vehicle type**, **settlement policy (balance cap, period)**, dispatch tuning (offer TTL, search radius). Every edit shows current value, takes effect immediately (Redis cache bust), and lands in the audit log.
- **Drivers** — verification queue (review uploaded documents → approve/reject), block/unblock, per-driver balance and history.
- **Operations** — live jobs map/list, job detail with full event + offer trail, manual cancel.
- **Ledger** — commission balances per driver, mark settlements, adjustments; totals per period.

Auth is the same Firebase login — the backend's admin router checks `role=admin` on the user row (promote via seed/SQL initially). MVP scope note: driver verification via this panel replaces the "manual flag in DB" from Phase 3.

---

## 5. Phased delivery

### Phase 0 — Foundations (~week 1)
- [ ] `backend/` scaffold: FastAPI, async SQLAlchemy, Alembic, Docker Compose (postgis + redis), Firebase Admin token verification, `/auth/sync`, `/me`
- [ ] Flutter: flavors (dev/prod), Firebase project wiring, Riverpod + go_router skeleton, auth flow (phone OTP), role-aware routing
- [ ] CI for both (ruff/pytest, flutter analyze/test)

### Phase 1 — Request & dispatch core (~weeks 2–3)
- [ ] Models + migrations: users, driver_profiles, jobs, job_offers, platform_config (+ audit)
- [ ] Quote endpoint (Directions distance + pricing from platform_config)
- [ ] Job creation + state machine + cancellation rules
- [ ] Dispatch service (Redis geo, sequential offers, timeouts)
- [ ] Customer request flow UI (map, pickers, quote, confirm)
- [ ] Driver home (availability, offer sheet, accept)
- [ ] FCM offer/status notifications

### Phase 2 — Live tracking & job execution (~weeks 4–5)
- [ ] WS channel: driver location up, job events down; reconnect handling
- [ ] Customer tracking screen (live marker, status timeline)
- [ ] Driver active-job screen (transitions, nav deep-link)
- [ ] Background location (Android foreground service, iOS entitlement)
- [ ] Delivery confirmation + cash settlement recording

### Phase 3 — Trust & polish (~week 6)
- [ ] Ratings both directions; driver rating shown at assignment
- [ ] Trip history + driver earnings screen
- [ ] Driver document upload (verification handled via admin panel in Phase 4; SQL flag until then)
- [ ] Empty/error/no-drivers states, es/en localization pass
- [ ] Admin API router: config CRUD, driver verify/block, jobs, ledger

### Phase 4 — Web client + super admin panel (~weeks 7–8)
- [ ] `web-client/` scaffold: Vite + React + TS, Firebase Auth web, generated API client from OpenAPI
- [ ] Customer request flow + quote + confirm (mobile-first)
- [ ] Live tracking page over the shared WS (+ polling fallback)
- [ ] Public share-track link (`/t/{job_token}`) + backend token endpoint; "share trip" button in Flutter
- [ ] Deploy to static hosting, CORS + web-restricted Maps key
- [ ] `admin/` SPA (§4.4): platform config editor (pricing, commission, settlement, dispatch), driver verification queue, live jobs, ledger/settlements

### Phase 5 — Post-MVP backlog
- Card/PSE payments via Wompi (see §6), photos of vehicle at pickup (damage evidence), scheduled tows, surge/zones pricing, broadcast dispatch, driver payout automation, SOS/support chat, SMS status fallback for web users.

### Phase 6 — Fleet owners
New role for owners of multiple grúas (see `docs/tasks/14-fleet-owner.md` and the fleet frames in the [design artifact](https://claude.ai/code/artifact/690138b9-1ac4-46eb-99ba-3aa26d444ac8)):
- `fleet_owner` role; `fleets` + `trucks` tables (truck fields migrate off `driver_profiles` so trucks exist independently of drivers)
- Ledger rolls up per fleet: one consolidated commission balance, one settlement clears all member drivers; balance-cap gating evaluates at fleet level
- Owner screens in the Flutter app: fleet status board, assign/invite driver to truck, fleet earnings
- Admin side: fleets & owners view (ADM-7)

---

## 6. Payments infrastructure (Phase 2 of payments — after cash MVP)

Cash stays the MVP settlement method, but the schema and backend are designed now so plugging in a gateway later is additive, not a rewrite.

### 6.1 Gateway comparison (LatAm focus)

| | **Wompi** (Bancolombia) | **MercadoPago** |
|---|---|---|
| Markets | Colombia only | AR, BR, MX, CO, CL, PE, UY |
| Local rails | **PSE**, Nequi, Bancolombia button/QR, cards | Cards, PSE (CO), account money, installments |
| Consumer wallet | No (pure gateway) | Yes — huge existing user base |
| Fees (CO, approx.) | ~2.65% + fixed for cards; PSE cheaper flat-ish | ~3.3%+ cards; varies by release timing |
| Payouts to third parties | Basic — payouts/dispersion API is more manual | **Marketplace split payments** (money splits to driver + platform at charge time, via OAuth-connected seller accounts) |
| Flutter support | Web checkout redirect / widget (webview) | Official mobile SDKs + Checkout Pro (webview/redirect) |
| Docs & sandbox | Good, simple REST, test keys | Extensive, sandbox + test users |

**Decision: Wompi first.** Launch market is Medellín (Colombia-only), where PSE + Nequi matter more than cards for one-off tow payments, fees are lower, and the API is simpler. Platform collects, then settles with drivers (see commission model in §2.5). MercadoPago stays on the roadmap as the multi-country/split-payments provider — the **gateway-agnostic `PaymentProvider` interface** keeps that a config change, not an architecture decision.

**Commission collection fits Wompi's model well:** since the platform charges drivers a fee per service rather than holding customer money as the primary model, digital payments can even launch commission-first — drivers top up / auto-pay their accumulated commission balance via Nequi or PSE, while customer fares stay cash. That's a smaller, lower-risk first integration than full customer checkout.

### 6.2 Integration architecture

```
Flutter app                    FastAPI                          Gateway (Wompi/MP)
    │  POST /jobs/{id}/pay        │                                   │
    ├────────────────────────────►│  create payment intent            │
    │                             ├──────────────────────────────────►│
    │   checkout_url / token      │◄──────────────────────────────────┤
    │◄────────────────────────────┤                                   │
    │  open webview / SDK ────────┼──────────────────────────────────►│  user pays (card/PSE/Nequi)
    │                             │        webhook (signed)           │
    │                             │◄──────────────────────────────────┤
    │                             │  verify signature → update        │
    │   WS/FCM: payment_confirmed │  payments row → job `paid`        │
    │◄────────────────────────────┤                                   │
```

Rules that keep this safe and sane:

1. **The app never talks to the gateway with secret keys.** Client gets only a checkout URL / public tokenization key. Card data never touches FastAPI (stays SAQ-A scope).
2. **Webhooks are the source of truth**, not the app's redirect callback. Verify the signature (Wompi: event checksum with events secret; MP: `x-signature` HMAC), then transition the payment. The redirect just triggers a "check status" poll for UX.
3. **Idempotency everywhere:** unique `reference` per payment attempt (e.g. `job_{id}_attempt_{n}`), idempotency keys on create calls, webhook handler tolerant of replays/out-of-order events.
4. **State machine for payments**, separate from job status: `pending → processing → approved | declined | expired | refunded`. Job completes on `approved` (or on cash confirmation — same interface).
5. **Async settlement risk (PSE):** PSE can sit in `PENDING` for minutes. UX: job can complete with payment `processing`; driver sees "payment in progress"; reconcile via webhook. Decide policy: block driver's next job until settled, or trust-and-flag.

### 6.3 Schema additions (create in Phase 1 so cash uses them too)

- **payments** — `id`, `job_id FK`, `provider (cash|wompi|mercadopago)`, `provider_ref`, `reference (unique)`, `amount`, `currency (COP)`, `method (cash|card|pse|nequi|wallet)`, `status`, `raw_webhook jsonb`, `created_at`, `settled_at`
- **payment_events** — append-only webhook/event log per payment (audit + replay debugging)
- **driver_ledger** — `driver_id`, `job_id`, `gross`, `commission`, `net`, `type (earning|payout|adjustment)`, `payout_id (nullable)` — works for cash from day one (commission owed to platform) and for digital (net owed to driver)
- **payouts** — batch payouts to drivers: `driver_id`, `amount`, `period`, `status`, `provider_ref`

The **ledger is the piece to build early**: with cash, drivers owe the platform commission; with digital, the platform owes drivers net fares. Same table handles both directions and makes the eventual gateway switch a settlement detail.

### 6.4 Money-flow models (pick one when going digital)

1. **Platform collects, pays out weekly** (works with Wompi or MP): all fares land in the platform account; scheduled dispersion to drivers minus commission. Simple, but the platform holds driver money (trust + possible regulatory weight).
2. **Split at charge time** (MercadoPago marketplace): each driver onboards via MP OAuth; every charge auto-splits driver-net / platform-fee. No held funds, but driver onboarding friction (every driver needs an MP account).
3. **Hybrid reality:** cash jobs keep running through the ledger regardless — digital never fully replaces cash for tow customers in LatAm.

### 6.5 Backend layout for payments

```
app/services/payments/
├── base.py            # PaymentProvider protocol: create_intent, get_status, refund, parse_webhook
├── cash.py            # trivial provider — driver confirms collection
├── wompi.py
└── mercadopago.py
app/api/payments.py     # POST /jobs/{id}/pay, GET /payments/{id}, POST /webhooks/{provider}
```

- Webhook endpoints are public but signature-verified; everything else behind auth.
- Store gateway keys in env/secret manager, separate sandbox vs prod key sets per flavor.
- Nightly reconciliation task: query gateway for the day's transactions, diff against `payments`, alert on mismatches.

### 6.6 Payments rollout phases

- **P0 (in MVP):** `payments` + `driver_ledger` tables live; cash provider records everything; commission tracked.
- **P1:** Wompi checkout (cards + PSE + Nequi) behind a feature flag, platform-collects model, webhook infra, reconciliation job.
- **P2:** Driver payouts UI + batch dispersion; refunds/cancellation fees.
- **P3 (if multi-country):** MercadoPago provider + split payments; currency handling beyond COP.

---

## 7. Risks & open questions

| Risk | Mitigation |
|---|---|
| iOS background location approval | Request entitlement early; App Store review needs clear justification copy |
| Google Maps API costs | Cache Directions per quote; use static map thumbnails in history |
| Driver supply at launch | Manual onboarding/verification is fine at MVP scale; admin dashboard later |
| Cash disputes | Location snapshots per transition + pickup photos (phase 4) |
| Offer race conditions | Row-level lock / `SELECT … FOR UPDATE` on accept; first accept wins |

**Decided:**
1. ~~Launch city/country?~~ → **Medellín, Colombia.** COP, es-CO, +57 OTP, Places biased to the Valle de Aburrá, Wompi as the gateway.
2. ~~Monetization model?~~ → **Commission charged to the driver per completed service**, percentage or flat per vehicle type (configurable), accrued in the driver ledger from the cash MVP onward.

3. ~~Commission shape & settlement policy?~~ → **Runtime-configurable from the super admin panel** (`platform_config`): commission mode (percent/flat) and rate per vehicle type, balance cap, settlement period. No deploys needed to change them.

**Open questions to settle during Phase 0:**
1. **Launch defaults** for the configurable values — initial commission rate, balance cap, base/per-km fares per vehicle type in COP (they're editable later, but Phase 1 needs seed values).
2. Do drivers need in-app chat/call with customer at MVP, or is a plain phone call button enough? (MVP suggestion: plain call button.)
