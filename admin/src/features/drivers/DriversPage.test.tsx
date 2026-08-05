import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { AppShell, AppRoutes } from '../../App';
import { authClient } from '../../auth';
import { strings } from '../../i18n/strings';

function renderDriversPage() {
  return render(
    <MemoryRouter
      initialEntries={['/drivers']}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('DriversPage (ADM-4)', () => {
  it('filters by verification status and verifies a pending driver', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderDriversPage();

    // All 8 seeded drivers show up by default.
    expect(await screen.findByText('Carlos Restrepo')).toBeInTheDocument();
    expect(screen.getByText('Luisa Fernanda Gómez')).toBeInTheDocument();

    // Filter down to pending verification only.
    await user.selectOptions(
      screen.getByLabelText(strings.drivers.filterVerified, { exact: false }),
      strings.drivers.unverified,
    );

    expect(screen.queryByText('Carlos Restrepo')).not.toBeInTheDocument();
    const row = screen.getByText('Luisa Fernanda Gómez').closest('tr') as HTMLElement;
    expect(within(row).getByText(strings.drivers.unverified)).toBeInTheDocument();

    // Verifying flips her badge to "Verificado" and removes the action.
    await user.click(within(row).getByRole('button', { name: strings.drivers.verify }));

    await within(row).findByText(strings.drivers.verified);
    expect(
      within(row).queryByRole('button', { name: strings.drivers.verify }),
    ).not.toBeInTheDocument();
  });
});
