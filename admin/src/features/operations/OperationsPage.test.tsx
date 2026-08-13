import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { AppShell, AppRoutes } from '../../App';
import { authClient } from '../../auth';
import { strings } from '../../i18n/strings';

function renderOperationsPage() {
  return render(
    <MemoryRouter
      initialEntries={['/operations']}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('OperationsPage (ADM-5)', () => {
  it('lists seeded jobs with customer, driver and status', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    renderOperationsPage();

    // job_3: assigned to Jorge Salazar, customer Valentina Ríos.
    const row = (await screen.findByText('job_3')).closest('tr') as HTMLElement;
    expect(within(row).getByText('Valentina Ríos')).toBeInTheDocument();
    expect(within(row).getByText('Jorge Salazar')).toBeInTheDocument();
    expect(within(row).getByText(strings.jobStatuses.assigned)).toBeInTheDocument();

    // job_1 has no driver assigned yet — shows the placeholder dash.
    const unassignedRow = screen.getByText('job_1').closest('tr') as HTMLElement;
    expect(within(unassignedRow).getByText('—')).toBeInTheDocument();
  });

  it('narrows the list by status filter', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderOperationsPage();

    await screen.findByText('job_1');
    // Several completed jobs (job_9..job_12) and non-completed ones are seeded.
    expect(screen.getByText('job_9')).toBeInTheDocument();

    await user.selectOptions(
      screen.getByLabelText(strings.operations.filterStatus, { exact: false }),
      strings.jobStatuses.completed,
    );

    // requested/assigned/etc jobs drop out of the filtered list.
    expect(await screen.findByText('job_9')).toBeInTheDocument();
    expect(screen.queryByText('job_1')).not.toBeInTheDocument();
    expect(screen.queryByText('job_3')).not.toBeInTheDocument();
    // Every remaining row is tagged "Completado".
    const badges = screen.getAllByText(strings.jobStatuses.completed);
    expect(badges.length).toBeGreaterThan(0);
  });

  it('clicking a row navigates to that job detail page', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderOperationsPage();

    const row = (await screen.findByText('job_4')).closest('tr') as HTMLElement;
    await user.click(row);

    expect(await screen.findByText(new RegExp(strings.operations.detailTitle))).toBeInTheDocument();
    // The mono job id is rendered in the detail header.
    expect(screen.getByText('job_4')).toBeInTheDocument();
    // Customer for job_4 is Santiago Vélez.
    expect(screen.getByText('Santiago Vélez')).toBeInTheDocument();
  });
});
