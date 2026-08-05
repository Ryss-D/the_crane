import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { AppShell, AppRoutes } from '../../App';
import { authClient } from '../../auth';
import { strings } from '../../i18n/strings';

function renderConfigPage() {
  return render(
    <MemoryRouter
      initialEntries={['/config']}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('ConfigPage (ADM-3)', () => {
  it('renders current values for all four config keys and submits an edit', async () => {
    // Sign in via the FakeAuth seam directly so the test skips the login form
    // (auth itself is covered elsewhere — this suite is about ADM-3).
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderConfigPage();

    // Wait for the config to load, then check each key's current value renders.
    expect(await screen.findByText(strings.config.keys.pricing)).toBeInTheDocument();
    expect(screen.getByText(strings.config.keys.commission)).toBeInTheDocument();
    expect(screen.getByText(strings.config.keys.settlement)).toBeInTheDocument();
    expect(screen.getByText(strings.config.keys.dispatch)).toBeInTheDocument();

    // Seeded dispatch config shows the launch-default offer TTL.
    expect(screen.getByText('30s')).toBeInTheDocument();

    // Open the dispatch editor (4th "Editar" button — pricing, commission,
    // settlement, dispatch) and change the offer TTL.
    const editButtons = screen.getAllByRole('button', { name: strings.config.edit });
    await user.click(editButtons[3]!);

    const dialog = await screen.findByRole('dialog', { name: strings.config.keys.dispatch });
    const ttlInput = within(dialog).getByLabelText(strings.config.fields.offer_ttl_seconds, {
      exact: false,
    });
    await user.clear(ttlInput);
    await user.type(ttlInput, '45');
    await user.click(within(dialog).getByRole('button', { name: strings.config.save }));

    // Modal closes and the new value is reflected.
    await screen.findByText('45s');
    expect(
      screen.queryByRole('dialog', { name: strings.config.keys.dispatch }),
    ).not.toBeInTheDocument();
  });
});
