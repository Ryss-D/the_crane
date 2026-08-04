# 04 — Dispatch & matching (DSP) · Phase 1

Finding the right grúa: driver availability, geo search, sequential offers.

- [ ] **DSP-1 — Driver availability + Redis geo index** *(deps: AUTH-5)*
  `PATCH /v1/drivers/me/status` (available|offline; blocked for unverified or over balance cap). Available drivers live in a Redis geo-set keyed by capacity (moto/car/both); location updates refresh it.
  *AC: geo-set query returns drivers within N km filtered by capacity; going offline removes the entry.*

- [ ] **DSP-2 — Sequential offer engine** *(deps: DSP-1, JOB-5)*
  On job `matching`: nearest fitting driver gets an offer (FCM + WS) with TTL from config (default 30s); reject/timeout → next driver; each offer recorded in `job_offers`. Radius widens once per config, then `no_drivers`.
  *AC: integration test with 3 fake drivers — first rejects, second times out, third accepts; offer trail complete.*

- [ ] **DSP-3 — Accept endpoint + race safety** *(deps: DSP-2)*
  `POST /v1/jobs/{id}/accept` — `SELECT … FOR UPDATE` on the job; first accept wins, job → `assigned`, driver → `on_job`, losers get 409.
  *AC: concurrent accept test — exactly one winner.*

- [ ] **DSP-4 — Offer timeout worker** *(deps: DSP-2)*
  Background task (asyncio / arq) expiring offers whose TTL passed and advancing the offer chain; safe across API restarts.
  *AC: killed-and-restarted API still expires stale offers.*

- [ ] **DSP-5 — No-drivers handling** *(deps: DSP-2)*
  Exhausted search → job `no_drivers`, customer notified (WS + FCM), retry action creates a fresh matching round.
  *AC: customer sees the state and can retry; retries don't duplicate offers to drivers who already rejected within X min.*
