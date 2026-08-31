import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { AppRoutes, AppShell } from '../../App';
import { api } from '../../api';
import { MockApi } from '../../api/mock';
import { TIMELINE_STATUSES } from '../../api/types';
import { strings } from '../../i18n/strings';
import { StatusTimeline } from './StatusTimeline';

/** Set only on MockApi (see src/api/index.ts) — every test here relies on
 * mocks, same as the rest of this file. */
function setDigitalFaresEnabled(enabled: boolean) {
  if (api instanceof MockApi) api.digitalFaresEnabled = enabled;
}

function renderAt(path: string) {
  return render(
    <MemoryRouter
      initialEntries={[path]}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('tracking page (WEB-3 skeleton)', () => {
  it('renders the full status timeline and driver card for the seeded mock job', async () => {
    renderAt('/jobs/demo');

    expect(
      await screen.findByRole('heading', { name: strings.tracking.title }),
    ).toBeInTheDocument();

    // Every happy-path status is rendered in the timeline.
    for (const status of TIMELINE_STATUSES) {
      expect(screen.getAllByText(strings.statuses[status]).length).toBeGreaterThan(0);
    }

    // The seeded demo job is frozen at en_route_pickup — marked as current step.
    const current = screen.getByRole('listitem', { current: 'step' });
    expect(current).toHaveTextContent(strings.statuses.en_route_pickup);

    // Driver is assigned → driver card shows.
    const driverCard = await screen.findByTestId('driver-card');
    expect(driverCard).toHaveTextContent('Carlos Restrepo');

    // FND-6 follow-up: pickup/dropoff pins from the job's own lat/lng — no
    // driver marker under mocks (useJobSocket no-ops, no `driver_location`
    // WS push to receive; `GET /v1/jobs/{id}` itself has no location field).
    await screen.findByTestId('tracking-map');
    const markers = screen.getAllByTestId('map-marker');
    expect(markers).toHaveLength(2);
    expect(markers.map((m) => m.getAttribute('data-marker-label'))).toEqual(['A', 'B']);
    expect(markers[0]).toHaveAttribute('data-marker-lat', '6.2088');
    expect(markers[1]).toHaveAttribute('data-marker-lat', '6.2273');

    // Call-driver button (parity with the Flutter app's CUS-4): a plain
    // tel: link, shown because the seeded demo driver has a phone.
    const callLink = screen.getByRole('link', { name: strings.tracking.callDriver });
    expect(callLink).toHaveAttribute('href', 'tel:+573001112233');
  });

  it('WEB-3/CUS-5: delivered shows the fare and a cash-confirm button that completes the job', async () => {
    const user = userEvent.setup();
    renderAt('/jobs/demo-delivered');

    expect(
      await screen.findByRole('heading', { name: strings.tracking.deliveredTitle }),
    ).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: strings.tracking.confirmCash }));

    // Completing surfaces the rating prompt and drops the confirm button.
    await screen.findByRole('heading', { name: strings.rating.title });
    expect(
      screen.queryByRole('button', { name: strings.tracking.confirmCash }),
    ).not.toBeInTheDocument();

    // RAT-1: rating actually posts (MockApi.submitRating) rather than being
    // a local-only stub.
    await user.click(screen.getByRole('radio', { name: '5' }));
    await user.click(screen.getByRole('button', { name: strings.rating.submit }));
    expect(await screen.findByText(strings.rating.thanks)).toBeInTheDocument();
  });

  it('renders the public share-track page from a token, without auth', async () => {
    renderAt('/t/demo-token');

    expect(
      await screen.findByRole('heading', { name: strings.tracking.publicTitle }),
    ).toBeInTheDocument();
    expect(screen.getByText(strings.tracking.publicNote)).toBeInTheDocument();
    for (const status of TIMELINE_STATUSES) {
      expect(screen.getAllByText(strings.statuses[status]).length).toBeGreaterThan(0);
    }

    // Matches the backend's TrackResponse/TrackDriver shape exactly: nested
    // driver.first_name/truck_plate, no eta_minutes (regression for a mismatch
    // found once the real backend contract existed to check against).
    expect(screen.getByText('Carlos')).toBeInTheDocument();
    expect(screen.getByText('TKX-482')).toBeInTheDocument();

    // FND-6 follow-up: the public poll response (`TrackResponse`) carries
    // `driver_location` directly (no WS needed here, unlike the authed
    // tracking page above) — three pins once a driver is assigned.
    await screen.findByTestId('tracking-map');
    const markers = screen.getAllByTestId('map-marker');
    expect(markers).toHaveLength(3);
    expect(markers.some((m) => m.getAttribute('data-marker-title') === 'Grúa')).toBe(true);
  });

  it('shows a not-found message for an unknown or expired share token (WEB-4)', async () => {
    renderAt('/t/this-token-does-not-exist');

    // react-query's default retry:1 means one retry with a ~1s backoff delay
    // before the query settles into an error state — give it more than the
    // default 1000ms findBy timeout.
    expect(await screen.findByRole('alert', {}, { timeout: 3000 })).toHaveTextContent(
      strings.tracking.notFound,
    );
    expect(
      screen.queryByRole('heading', { name: strings.tracking.publicTitle }),
    ).not.toBeInTheDocument();
  });
});

describe('PAY-4: digital fare checkout', () => {
  const originalLocation = window.location;

  beforeEach(() => {
    // A plain object stand-in — `TrackingPage` only ever assigns `.href` on
    // it, and jsdom's real `Location` throws "Not implemented: navigation"
    // if a test actually lets that assignment try to navigate.
    Object.defineProperty(window, 'location', {
      configurable: true,
      writable: true,
      value: { ...originalLocation, href: '' },
    });
  });

  afterEach(() => {
    Object.defineProperty(window, 'location', {
      configurable: true,
      writable: true,
      value: originalLocation,
    });
  });

  it('redirects to the fake checkout URL when PSE/card is chosen with the flag on', async () => {
    setDigitalFaresEnabled(true);
    const user = userEvent.setup();
    renderAt('/jobs/demo-delivered');

    await screen.findByRole('heading', { name: strings.tracking.deliveredTitle });
    await user.click(screen.getByRole('button', { name: strings.tracking.payDigitalToggle }));
    await user.click(screen.getByRole('radio', { name: strings.paymentMethods.pse }));
    await user.click(screen.getByRole('button', { name: strings.tracking.payDigitalSubmit }));

    await waitFor(() =>
      expect(window.location.href).toBe('https://checkout.wompi.co/fake/demo-delivered_pse'),
    );
  });

  it('shows the Nequi in-app-approval message with no redirect when Nequi is chosen with the flag on', async () => {
    setDigitalFaresEnabled(true);
    const user = userEvent.setup();
    renderAt('/jobs/demo-delivered');

    await screen.findByRole('heading', { name: strings.tracking.deliveredTitle });
    await user.click(screen.getByRole('button', { name: strings.tracking.payDigitalToggle }));
    await user.click(screen.getByRole('radio', { name: strings.paymentMethods.nequi }));
    await user.click(screen.getByRole('button', { name: strings.tracking.payDigitalSubmit }));

    expect(await screen.findByText(strings.tracking.nequiPending)).toBeInTheDocument();
    expect(window.location.href).toBe('');
  });

  it('shows a clear "not available yet" message on the 422 when the flag is off', async () => {
    setDigitalFaresEnabled(false);
    const user = userEvent.setup();
    renderAt('/jobs/demo-delivered');

    await screen.findByRole('heading', { name: strings.tracking.deliveredTitle });
    await user.click(screen.getByRole('button', { name: strings.tracking.payDigitalToggle }));
    // Default-selected method (card) is fine — any non-cash method 422s.
    await user.click(screen.getByRole('button', { name: strings.tracking.payDigitalSubmit }));

    expect(await screen.findByRole('alert')).toHaveTextContent(
      strings.tracking.digitalFaresUnavailable,
    );
    expect(window.location.href).toBe('');
    // Cash still works unchanged on the same screen.
    await user.click(screen.getByRole('button', { name: strings.tracking.confirmCash }));
    await screen.findByRole('heading', { name: strings.rating.title });
  });
});

describe('StatusTimeline', () => {
  it('marks terminal failures with an alert banner', () => {
    render(<StatusTimeline status="no_drivers" />);
    expect(screen.getByRole('alert')).toHaveTextContent(strings.statuses.no_drivers);
  });
});
