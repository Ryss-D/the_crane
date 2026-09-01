import type { ReactNode } from 'react';
import { act, render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Job } from '../../api/types';
import { strings } from '../../i18n/strings';

/**
 * WEB-3 follow-up (2026-08-31): closes the one real gap the WEB-3 entry in
 * `docs/tasks/10-web-client.md` flagged after the map/`driver_location`
 * wiring landed -- `useJobSocket` itself is unit-tested in isolation
 * (`src/ws/useJobSocket.test.tsx`, 8 passing tests against a fake
 * WebSocket), but nothing proved `TrackingPage` actually *consumes* a live
 * `driver_location` push and turns it into a rendered map marker. Every
 * existing `TrackingPage.test.tsx` test runs under `MockApi`, where
 * `useJobSocket` permanently no-ops (see that file's own comment) -- so the
 * page-level wiring was untested even though the hook was.
 *
 * This file forces the same real (non-mock) code path
 * `useJobSocket.test.tsx` forces, for the same reason: `useJobSocket`'s
 * `useMocks` const is `VITE_USE_MOCKS !== 'false' || MODE === 'test'`,
 * evaluated once at module scope, so getting the *real* WS client requires
 * `vi.stubEnv` on both plus `vi.resetModules()` + a dynamic import taken
 * fresh per test. The same flip also switches `src/api/index.ts`'s `api`
 * singleton to the real `HttpApi` (its `useMocks` only checks
 * `VITE_USE_MOCKS`, not `MODE`) -- rather than dragging in a real backend or
 * rebuilding `RequestPage`'s full sign-in flow just to prove a map marker
 * updates, `fetch` is stubbed to resolve one fixture `Job` for
 * `GET /v1/jobs/:id` (the only call this page makes under test), and
 * `../../auth/singleton` is mocked the same way `useJobSocket.test.tsx`
 * mocks it (a fake `getIdToken`) so `HttpApi`'s auth header and the WS
 * client's token both resolve without touching Firebase. `FakeWebSocket` is
 * the same minimal harness `useJobSocket.test.tsx` built (duplicated here
 * rather than imported since that file doesn't export it, and it's ~25
 * lines) -- driven by hand through its `on*` handlers exactly the same way.
 *
 * `TrackingPage` is rendered directly under a `MemoryRouter`/
 * `QueryClientProvider` pair (not the full `AppShell`/`AppRoutes`
 * `TrackingPage.test.tsx` uses) since `AppShell` wraps in `AuthProvider`,
 * which drives real sign-in state this test has no need for -- the page
 * itself only needs a route param and a query client, both provided here
 * directly. This is a deliberately narrower harness than the rest of the
 * suite, scoped to proving the one thing that was missing: a real
 * `driver_location` WS message reaching a real third map marker.
 */
class FakeWebSocket {
  static readonly CONNECTING = 0;
  static readonly OPEN = 1;
  static readonly CLOSING = 2;
  static readonly CLOSED = 3;

  static instances: FakeWebSocket[] = [];
  static reset(): void {
    FakeWebSocket.instances = [];
  }

  readyState = FakeWebSocket.CONNECTING;
  readonly sent: string[] = [];
  onopen: (() => void) | null = null;
  onmessage: ((event: MessageEvent<string>) => void) | null = null;
  onclose: (() => void) | null = null;
  onerror: (() => void) | null = null;

  constructor(readonly url: string) {
    FakeWebSocket.instances.push(this);
  }

  send(data: string): void {
    this.sent.push(data);
  }

  close(): void {
    this.readyState = FakeWebSocket.CLOSED;
  }

  triggerOpen(): void {
    this.readyState = FakeWebSocket.OPEN;
    this.onopen?.();
  }

  triggerMessage(data: unknown): void {
    this.onmessage?.({ data: JSON.stringify(data) } as MessageEvent<string>);
  }
}

const TEST_ID_TOKEN = 'test-id-token';

vi.mock('../../auth/singleton', () => ({
  authClient: { getIdToken: vi.fn().mockResolvedValue(TEST_ID_TOKEN) },
}));

const JOB_ID = 'job-live-1';

const FIXTURE_JOB: Job = {
  id: JOB_ID,
  status: 'en_route_pickup',
  vehicle_type: 'car',
  pickup_lat: 6.2088,
  pickup_lng: -75.5673,
  dropoff_lat: 6.2273,
  dropoff_lng: -75.5697,
  pickup_address: 'Parque Berrío',
  dropoff_address: 'Estadio',
  quoted_price: 45000,
  final_price: null,
  distance_km: 3.2,
  driver: null,
  share_token: 'share-live-1',
  created_at: '2026-08-31T00:00:00Z',
  async_payment_url: null,
};

function renderTrackingPage(queryClient: QueryClient, element: ReactNode) {
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter
        initialEntries={[`/jobs/${JOB_ID}`]}
        future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
      >
        <Routes>
          <Route path="/jobs/:id" element={element} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('TrackingPage live driver marker over a real WebSocket (WEB-3)', () => {
  let queryClient: QueryClient;
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    vi.stubEnv('VITE_USE_MOCKS', 'false');
    vi.stubEnv('MODE', 'development');
    vi.resetModules();
    FakeWebSocket.reset();
    vi.stubGlobal('WebSocket', FakeWebSocket);

    fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => FIXTURE_JOB,
    });
    vi.stubGlobal('fetch', fetchMock);

    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false, refetchOnWindowFocus: false } },
    });
  });

  afterEach(() => {
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it('wires a real driver_location WS push into a third map marker with the pushed coordinates', async () => {
    const { TrackingPage } = await import('./TrackingPage');

    renderTrackingPage(queryClient, <TrackingPage />);

    // Job loads over the stubbed `fetch` (real HttpApi, real auth header).
    expect(
      await screen.findByRole('heading', { name: strings.tracking.title }),
    ).toBeInTheDocument();
    await screen.findByTestId('tracking-map');
    expect(fetchMock).toHaveBeenCalledWith(
      `http://localhost:8000/v1/jobs/${JOB_ID}`,
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: `Bearer ${TEST_ID_TOKEN}` }),
      }),
    );

    // Only the two static pickup/dropoff pins exist before any WS push.
    expect(screen.getAllByTestId('map-marker')).toHaveLength(2);

    // The real (non-mock) useJobSocket connects and subscribes.
    await waitFor(() => expect(FakeWebSocket.instances).toHaveLength(1));
    const socket = FakeWebSocket.instances[0]!;
    expect(socket.url).toBe(`ws://localhost:8000/v1/ws?token=${TEST_ID_TOKEN}`);
    act(() => socket.triggerOpen());
    await waitFor(() =>
      expect(socket.sent).toContain(JSON.stringify({ type: 'subscribe', job_id: JOB_ID })),
    );

    // Drive a real driver_location push through the fake socket.
    act(() => {
      socket.triggerMessage({ type: 'driver_location', job_id: JOB_ID, lat: 6.21, lng: -75.58 });
    });

    // A genuinely new third marker appears -- not the pickup/dropoff pins.
    await waitFor(() => expect(screen.getAllByTestId('map-marker')).toHaveLength(3));
    const driverMarker = screen
      .getAllByTestId('map-marker')
      .find((m) => m.getAttribute('data-marker-title') === 'Grúa');
    expect(driverMarker).toBeDefined();
    expect(driverMarker).toHaveAttribute('data-marker-lat', '6.21');
    expect(driverMarker).toHaveAttribute('data-marker-lng', '-75.58');

    // Bonus: a second push with different coordinates updates the same
    // marker in place (still exactly one driver marker, not a second one).
    act(() => {
      socket.triggerMessage({ type: 'driver_location', job_id: JOB_ID, lat: 6.25, lng: -75.55 });
    });

    await waitFor(() =>
      expect(
        screen
          .getAllByTestId('map-marker')
          .find((m) => m.getAttribute('data-marker-title') === 'Grúa'),
      ).toHaveAttribute('data-marker-lat', '6.25'),
    );
    const markersAfterUpdate = screen.getAllByTestId('map-marker');
    expect(markersAfterUpdate).toHaveLength(3);
    const updatedDriverMarker = markersAfterUpdate.find(
      (m) => m.getAttribute('data-marker-title') === 'Grúa',
    );
    expect(updatedDriverMarker).toHaveAttribute('data-marker-lng', '-75.55');
  });
});
