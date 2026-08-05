# 05 — Realtime & tracking (TRK) · Phase 2

WebSocket layer for live positions and job events; FCM covers backgrounded apps.

- [x] **TRK-1 — Authed WebSocket endpoint** *(deps: FND-5)*
  `WS /v1/ws`: token auth on connect, channel routing (driver location up; job events down), Redis pub/sub between API workers, heartbeat + stale-connection cleanup.
  *AC: two clients on different workers receive each other's job events; dead sockets pruned.*

- [x] **TRK-2 — Driver location pipeline** *(deps: TRK-1, DSP-1)*
  Driver sends position every ~5s over WS → Redis geo-set + live channel of the active job; REST fallback `PUT /v1/drivers/me/location`. Snapshot to Postgres on every job transition.
  *AC: customer channel receives positions ≤5s stale; snapshots present per transition.*

- [x] **TRK-3 — Job event broadcasting** *(deps: TRK-1, JOB-3)*
  Every state transition publishes to the job channel and triggers FCM (customer: status changes; driver: offers/cancellations). FCM payloads are data messages with job id for rehydration.
  *AC: app killed → FCM arrives; app open → WS event arrives; no double-handling.*

- [ ] **TRK-4 — Flutter WS client** *(deps: FND-4)*
  `core/ws/`: connect lifecycle bound to auth state, exponential reconnect, typed event stream (freezed events), rehydrate via `GET /jobs/{id}` on reconnect.
  *AC: airplane-mode toggle recovers the stream and reconciles missed events.*

- [ ] **TRK-5 — Driver background location** *(deps: TRK-2)*
  geolocator foreground-service mode (Android) + iOS background location entitlement, active only while available/on-job. Battery-sane intervals.
  *AC: locked-screen Android device keeps streaming during an active job; iOS entitlement justification drafted for review.*

- [ ] **TRK-6 — Share-track token backend** *(deps: TRK-3)*
  Mint `job_token` at creation; `GET /v1/track/{token}` + public WS/poll channel exposing only position, status, ETA (no PII beyond driver first name/plate).
  *AC: token works logged-out; expires after job completion + 24h.*
