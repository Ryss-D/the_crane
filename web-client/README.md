# The Crane — Customer Web App (React)

> Note: this lives in `web-client/` because `web/` is the Flutter web build target.

No-install customer flow: request and track a grúa from the browser. Customer role only — drivers use the Flutter app. See `docs/PLAN.md` §4 and `docs/tasks/10-web-client.md`.

## Stack

- Vite + React 18 + TypeScript, Tailwind v4 (mobile-first)
- TanStack Query (REST + 10s polling) + Zustand (small active-job store)
- react-router (`/` request · `/jobs/:id` tracking · `/t/:token` public share-track)
- Firebase Auth web (phone OTP — same accounts as the mobile app) — **stubbed, see below**
- `@vis.gl/react-google-maps`, Places Autocomplete — **stubbed, see below**
- API client generated from the FastAPI OpenAPI spec (`openapi-typescript`) — **hand-written for now, see below**

Includes the public share-track page (`/t/{job_token}`) — read-only live tow map, no login.

Scaffolded in task `WEB-1`.

## Getting started

```sh
npm install
npm run dev        # http://localhost:5173 — mocks on by default
npm run build      # tsc -b + vite build
npm run test       # vitest (jsdom + testing-library)
npm run lint       # eslint flat config
npm run format     # prettier
```

Mock mode seeds a demo job: open `/jobs/demo` (customer view) or `/t/demo-token`
(public share view) directly. Jobs you create through the request flow progress
through the status machine on a timer, so the tracking page visibly advances.

## The seams (mock today → real later)

| Seam      | Interface                                   | Today                                                                            | Later                                                                                                                                                                    |
| --------- | ------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| API       | `CraneApi` (`src/api/client.ts`)            | `MockApi` (`src/api/mock.ts`) — seeded data + latency + timed status progression | `HttpApi` fetch wrappers for `POST /v1/jobs/quote`, `POST /v1/jobs`, `GET /v1/jobs/{id}`, `GET /v1/track/{token}`                                                        |
| API types | `src/api/types.ts` (hand-written)           | mirrors the backend contract by hand                                             | **TODO(openapi):** replaced by `npm run client:generate` (`openapi-typescript`) once the spec stabilizes — see `src/api/README.md`                                       |
| Auth      | `AuthClient` (`src/auth/types.ts`)          | `FakeAuth` — any phone → logged in, localStorage session                         | **TODO(FND-1):** Firebase web SDK phone-OTP implementation of the same interface (`getIdToken()`, `signInWithPhone()`, `signOut()`), selected in `src/auth/singleton.ts` |
| Maps      | placeholder boxes in request/tracking pages | dashed "Mapa próximamente" box                                                   | **TODO(FND-6):** `@vis.gl/react-google-maps` + Places Autocomplete + browser-geolocation pickup (web-restricted key)                                                     |
| Realtime  | `src/ws/useJobSocket.ts`                    | no-op — pages poll via TanStack Query every 10s                                  | **TODO(TRK-1/WEB-3):** native WebSocket to `/v1/ws`, polling stays as the fallback                                                                                       |

Selection: `VITE_USE_MOCKS` (default **true**). Set `VITE_USE_MOCKS=false` +
`VITE_API_BASE_URL` in `.env.local` to hit the real backend (see `.env.example`).

## Layout

```
src/
├── api/          # CraneApi seam: types.ts (hand-written, → generated), client.ts (HttpApi), mock.ts
├── auth/         # AuthClient seam: FakeAuth today, Firebase later (TODO FND-1)
├── features/
│   ├── request/  # WEB-2: pickup/dropoff, vehicle type, quote (COP), confirm
│   ├── tracking/ # WEB-3: /jobs/:id timeline + driver card; /t/:token public page
│   └── rating/   # rating stub (local-only for now)
├── ws/           # socket seam stub — polling fallback constant lives here
├── store/        # Zustand active-job store
├── i18n/         # es-CO strings + COP formatting (Intl.NumberFormat es-CO)
└── ui/           # Button, Card, StatusPill
```
