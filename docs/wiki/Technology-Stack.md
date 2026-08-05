# Technology Stack

## Backend (`backend/`)

| Technology | Role | Why |
|---|---|---|
| FastAPI (Python 3.12) | REST + WebSocket API | Async-native, OpenAPI schema for free (drives generated TS clients), fast to build |
| PostgreSQL + PostGIS | System of record + geo queries | Real relational integrity for money/jobs; PostGIS `<->` distance ordering for nearest-driver search |
| SQLAlchemy (async) + Alembic | ORM + migrations | De-facto standard; async matches FastAPI |
| Redis | Live driver locations (geo-sets), pub/sub across workers, config cache | Positions are ephemeral by nature — Postgres only stores snapshots at job transitions |
| Firebase Admin SDK | Verifies phone-OTP ID tokens | Identity outsourced to Firebase; backend stays stateless about credentials |
| FCM | Push (job offers, status changes) | Only reliable channel to backgrounded/killed mobile apps |
| uv + ruff + pytest | Packaging, lint/format, tests | Single fast toolchain, enforced in CI |
| Docker Compose | Local stack (api + postgis + redis) | One-command dev environment |

## Mobile app (root — Flutter)

| Technology | Role | Why |
|---|---|---|
| Flutter | Single app, role switch (customer/driver/fleet-owner) | One codebase + one store listing at MVP scale |
| Riverpod (+ codegen) | State management | Compile-safe DI, testable, async-first |
| go_router | Routing with auth + role guards | Declarative redirect logic per auth/role state |
| dio | HTTP | Interceptor injects/refreshes Firebase ID token |
| freezed + json_serializable | Models | Immutable models mirroring API schemas |
| firebase_auth / firebase_messaging | Phone OTP + push | See identity/push decisions |
| google_maps_flutter + geolocator | Maps, GPS streaming | Best coverage in Colombia; foreground-service mode for driver tracking |
| --dart-define-from-file | Flavors (dev/prod) | Env-specific API URLs and keys without code changes |

## Web (`web-client/`, `admin/`) — React over Vue (decided 2026-08-04)

| Technology | Role | Why |
|---|---|---|
| Vite + React + TypeScript | Both SPAs | Deepest ecosystem; one mental model for both web apps |
| TanStack Query | Server state | Cache/retry/invalidations for a REST API done right |
| Zustand | Small client state (active job, socket) | Minimal; most state is server state |
| @vis.gl/react-google-maps | Maps | Best-maintained React binding for Google Maps |
| openapi-typescript (generated client) | API contract | FastAPI's OpenAPI spec is the single source of truth for both SPAs |
| Tailwind | Styling | Mobile-first for web-client; fast iteration for admin |
| Firebase Auth (web SDK) | Same phone-OTP accounts as mobile | Zero backend changes; one identity across surfaces |

## Third-party services

| Service | Role | Notes |
|---|---|---|
| Firebase (Auth + FCM) | Identity, push | The only Firebase products used — no Firestore |
| Google Maps Platform | Maps SDKs, Places (Valle de Aburrá bias), Directions (road distance for quotes) | Restricted keys per platform |
| Wompi (Bancolombia) | Payments, Phase 5 | PSE + Nequi + cards; commission-first rollout — see ADR-8 |
| GitHub Actions | CI (ruff/pytest with PostGIS+Redis services; flutter analyze/test) | Path-filtered per workspace |
| Sentry (planned, OPS-6) | Error tracking across API + apps | |
