import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { AppShell, AppRoutes } from '../../App';
import { authClient } from '../../auth';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';

// getByText's default matcher normalizes the DOM's text (collapsing the NBSP
// that Intl's currency formatter inserts after "$" into a plain space) but
// does NOT normalize the string you pass in — so comparing directly against
// formatCOP(...)'s raw output never matches. Normalize on this side too.
function cop(amount: number): string {
  return formatCOP(amount).replace(/\u00A0/g, ' ');
}

function renderJobDetail(jobId: string) {
  return render(
    <MemoryRouter
      initialEntries={[`/operations/${jobId}`]}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('JobDetailPage (ADM-5)', () => {
  it('renders the full offer trail and job info for a seeded job', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    // job_15 (no_drivers) was offered to three drivers: two rejections and a
    // timeout, none accepted.
    renderJobDetail('job_15');

    expect(await screen.findByText(new RegExp(strings.operations.detailTitle))).toBeInTheDocument();

    // Job info card: customer, pickup/dropoff, distance, quoted price.
    expect(screen.getByText('Gabriela Salazar')).toBeInTheDocument();
    expect(screen.getByText('Cl. 12 Sur #43-20, El Poblado, Medellín')).toBeInTheDocument();
    expect(screen.getByText('Taller Camionetas Sur, Envigado')).toBeInTheDocument();
    expect(screen.getByText(cop(70000 + 7 * 5500))).toBeInTheDocument();

    // Full offer trail: every offered driver and their response shows up.
    const offerHeading = screen.getByText(strings.operations.offerTrail);
    const offerCard = offerHeading.closest('div') as HTMLElement;
    expect(within(offerCard).getByText('Carlos Restrepo')).toBeInTheDocument();
    expect(within(offerCard).getByText('Andrea Muñoz')).toBeInTheDocument();
    expect(within(offerCard).getByText('Jorge Salazar')).toBeInTheDocument();
    expect(within(offerCard).getAllByText(strings.offerResponses.rejected)).toHaveLength(2);
    expect(within(offerCard).getByText(strings.offerResponses.timeout)).toBeInTheDocument();
  });

  it('shows "no offers" when a seeded job has no offer trail yet', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    // job_1 is freshly requested — no driver has been offered the job yet.
    renderJobDetail('job_1');

    await screen.findByText(new RegExp(strings.operations.detailTitle));
    expect(screen.getByText(strings.operations.noOffers)).toBeInTheDocument();
  });

  it('lets an admin cancel a non-terminal job with a reason', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    // job_4 is en_route_pickup — not a terminal state, so cancel is allowed.
    renderJobDetail('job_4');

    await screen.findByText(new RegExp(strings.operations.detailTitle));
    expect(screen.getByText(strings.jobStatuses.en_route_pickup)).toBeInTheDocument();

    await user.type(
      screen.getByLabelText(strings.operations.cancelReasonLabel),
      'Cliente no contesta',
    );
    await user.click(screen.getByRole('button', { name: strings.operations.cancelConfirm }));

    // The job flips to "Cancelado" and the cancel reason is shown; the
    // now-terminal job no longer offers the cancel action.
    expect(await screen.findByText(strings.jobStatuses.cancelled)).toBeInTheDocument();
    expect(screen.getByText(/Cliente no contesta/)).toBeInTheDocument();
    expect(screen.queryByText(strings.operations.cancel)).not.toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: strings.operations.cancelConfirm }),
    ).not.toBeInTheDocument();
  });

  it('hides the manual cancel action for a job already in a terminal state', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    // job_9 is completed — a terminal state per the job state machine
    // (docs/PLAN.md §2.3) — so manual cancel must not be offered.
    renderJobDetail('job_9');

    await screen.findByText(new RegExp(strings.operations.detailTitle));
    expect(screen.getByText(strings.jobStatuses.completed)).toBeInTheDocument();
    expect(screen.queryByText(strings.operations.cancel)).not.toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: strings.operations.cancelConfirm }),
    ).not.toBeInTheDocument();
  });
});
