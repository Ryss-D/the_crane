import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { AppRoutes, AppShell } from '../../App';
import { TIMELINE_STATUSES } from '../../api/types';
import { strings } from '../../i18n/strings';
import { StatusTimeline } from './StatusTimeline';

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
    expect(await screen.findByTestId('driver-card')).toHaveTextContent('Carlos Restrepo');
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

describe('StatusTimeline', () => {
  it('marks terminal failures with an alert banner', () => {
    render(<StatusTimeline status="no_drivers" />);
    expect(screen.getByRole('alert')).toHaveTextContent(strings.statuses.no_drivers);
  });
});
