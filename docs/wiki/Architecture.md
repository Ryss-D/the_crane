# Architecture

## System overview

```
┌─────────────────────────┐   ┌─────────────────────────┐   ┌──────────────────┐
│      Flutter app        │   │   React web client       │   │  React admin SPA │
│ customer/driver/fleet   │   │ (customer, no install)   │   │  (role=admin)    │
└───┬───────┬─────────┬───┘   └───────────┬──────────────┘   └────────┬─────────┘
    │  Firebase Auth  │ Google Maps /     │  same REST + WS           │
    │  (ID tokens)    │ Places/Directions │  Firebase Auth (web)      │
    ▼       │         ▼◄──────────────────┴───────────────────────────┘
┌─────────────────────────┐        ┌──────────────┐
│        FastAPI           │◄──────►│  PostgreSQL  │  system of record
│  REST + WebSockets       │        │  + PostGIS   │  (geo queries)
│  - verifies Firebase JWT │        └──────────────┘
│  - dispatch/matching     │        ┌──────────────┐
│  - pricing + ledger      │───────►│    Redis     │  live driver locations,
│  - job state machine     │        │              │  pub/sub, config cache
└───────────┬─────────────┘        └──────────────┘
            ▼
      Firebase FCM  (push: job offers, status changes)
```

**Division of labor:** Firebase handles identity (phone OTP) and push delivery — nothing else. All domain data lives in Postgres; PostGIS answers "nearest available truck that fits this vehicle"; Redis holds only ephemeral state (driver positions refreshed ~5s, pub/sub between API workers, config cache). WebSockets serve foregrounded apps; FCM data messages cover backgrounded/killed apps, and opening the app rehydrates from `GET /jobs/{id}`.

## Data model (core)

- **users** — firebase_uid, role (customer | driver | admin | fleet_owner), contact, fcm_token
- **driver_profiles** — status, verified, documents, rating_avg
- **trucks** — plate, type, capacity (moto|car|both), `driver_id` nullable, `fleet_id` nullable → a truck exists independently of a driver, so fleets attach later without migration
- **fleets** — owner user, Phase 6
- **customer_vehicles** — saved moto/car details for repeat requests
- **jobs** — PostGIS pickup/dropoff points, status, per-transition timestamps, quoted/final price, **config snapshot** (the pricing/commission values it was created under)
- **job_offers** — audit trail of the dispatch fan-out (offered/responded/timeout per driver)
- **payments / payment_events / driver_ledger / payouts** — the money spine (see [[Architecture Decisions]] ADR-7/8)
- **platform_config** — versioned runtime config with audit log
- **ratings**, **driver_location_snapshots** (position at each job transition, for disputes)

## Job state machine

```
requested → matching → assigned → en_route_pickup → arrived_pickup
              │            │                              │
              ▼            ▼                              ▼
          no_drivers   cancelled                       loading → in_transit → delivered → completed
```

One service owns the allowed-transitions map. Every transition is timestamped, snapshots the driver location, broadcasts on the job's WS channel, and triggers FCM. Customer cancels free until `assigned` + grace; driver cancellation returns the job to `matching`. On `completed`, the commission ledger entry is written from the job's config snapshot.

## Dispatch (MVP)

Sequential nearest-first offers: Redis geo-query for available drivers whose truck capacity fits, offer to nearest with a TTL (config, default 30s), on reject/timeout move to next, widen radius once, then `no_drivers`. First `accept` wins via `SELECT … FOR UPDATE`. Broadcast dispatch is a later upgrade.

## Environments

Docker Compose locally (api + postgis + redis); deploy target Cloud Run / Fly.io / Railway + managed Postgres; static hosting for the two React SPAs; dev/prod separation across Firebase projects, Maps keys, and Wompi sandbox/prod.
