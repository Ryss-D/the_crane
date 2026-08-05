import { render, screen } from '@testing-library/react';
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
});

describe('StatusTimeline', () => {
  it('marks terminal failures with an alert banner', () => {
    render(<StatusTimeline status="no_drivers" />);
    expect(screen.getByRole('alert')).toHaveTextContent(strings.statuses.no_drivers);
  });
});
