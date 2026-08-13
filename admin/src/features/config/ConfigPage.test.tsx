import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AppShell, AppRoutes } from '../../App';
import { api } from '../../api';
import { authClient } from '../../auth';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';

// formatCOP renders "$ 77.000" (non-breaking space) but RTL's default
// text normalizer only collapses/trims whitespace on the DOM candidate, not
// on the raw string passed in as the matcher — so a literal formatCOP()
// call as the search term never matches. Swap the NBSP for a regular space
// to line up with what the normalizer produces from the rendered DOM.
function copText(amount: number): string {
  return formatCOP(amount).replace(/ /g, ' ');
}

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

  it('opens the pricing editor and saves an edited fare', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderConfigPage();

    await screen.findByText(strings.config.keys.pricing);
    const editButtons = screen.getAllByRole('button', { name: strings.config.edit });
    await user.click(editButtons[0]!); // pricing is the first card

    const dialog = await screen.findByRole('dialog', { name: strings.config.keys.pricing });
    // Three vehicle-type fieldsets each expose a "base_fare" input — the
    // first one belongs to "moto" (VEHICLE_TYPES[0]).
    const baseFareInputs = within(dialog).getAllByLabelText(strings.config.fields.base_fare, {
      exact: false,
    });
    await user.clear(baseFareInputs[0]!);
    await user.type(baseFareInputs[0]!, '77000');
    await user.click(within(dialog).getByRole('button', { name: strings.config.save }));

    await screen.findByText(copText(77000), { exact: false });
    expect(
      screen.queryByRole('dialog', { name: strings.config.keys.pricing }),
    ).not.toBeInTheDocument();
  });

  it('switches commission mode to flat and saves a flat rate', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderConfigPage();

    await screen.findByText(strings.config.keys.commission);
    const editButtons = screen.getAllByRole('button', { name: strings.config.edit });
    await user.click(editButtons[1]!); // commission is the second card

    const dialog = await screen.findByRole('dialog', { name: strings.config.keys.commission });

    // Exercise the percent-mode rate input (0-100 scale, converted to a
    // 0-1 fraction) before switching modes below.
    const motoPercentInput = within(dialog).getAllByLabelText(strings.config.fields.rate, {
      exact: false,
    })[0]!;
    await user.clear(motoPercentInput);
    await user.type(motoPercentInput, '20');

    const modeSelect = within(dialog).getByLabelText(strings.config.fields.mode);
    await user.selectOptions(modeSelect, strings.config.commissionModes.flat);

    // Switching to "flat" swaps the 0-100 percent input for a plain COP
    // input, keyed by "<vehicle type> — Tasa". The old percent-mode
    // fractions (e.g. 0.15) are left in place and are no longer valid
    // integers under the flat input's implicit step=1, so every field must
    // be rewritten or the browser's native validation silently blocks
    // submission.
    const rateInputs = within(dialog).getAllByLabelText(strings.config.fields.rate, {
      exact: false,
    });
    for (const input of rateInputs) {
      await user.clear(input);
      await user.type(input, '6000');
    }
    await user.click(within(dialog).getByRole('button', { name: strings.config.save }));

    await screen.findByText(strings.config.commissionModes.flat);
    expect(screen.getAllByText(copText(6000))).toHaveLength(3);
    expect(
      screen.queryByRole('dialog', { name: strings.config.keys.commission }),
    ).not.toBeInTheDocument();
  });

  it('removes the settlement balance cap and changes the settlement period', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderConfigPage();

    await screen.findByText(strings.config.keys.settlement);
    const editButtons = screen.getAllByRole('button', { name: strings.config.edit });
    await user.click(editButtons[2]!); // settlement is the third card

    const dialog = await screen.findByRole('dialog', { name: strings.config.keys.settlement });
    await user.click(within(dialog).getByLabelText(strings.config.noCap));
    await user.selectOptions(
      within(dialog).getByLabelText(strings.config.fields.settlement_period),
      strings.config.settlementPeriods.monthly,
    );
    await user.click(within(dialog).getByRole('button', { name: strings.config.save }));

    // The summary now shows "no cap" instead of a formatted COP amount, and
    // the info badge (only rendered when a cap is set) disappears.
    await screen.findByText(strings.config.settlementPeriods.monthly);
    expect(screen.getAllByText(strings.config.noCap).length).toBeGreaterThan(0);
    expect(
      screen.queryByRole('dialog', { name: strings.config.keys.settlement }),
    ).not.toBeInTheDocument();
  });

  it('shows a save error banner when the update request fails', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    const updateSpy = vi
      .spyOn(api, 'updateConfig')
      .mockRejectedValueOnce(new Error('network down'));
    renderConfigPage();

    await screen.findByText(strings.config.keys.dispatch);
    const editButtons = screen.getAllByRole('button', { name: strings.config.edit });
    await user.click(editButtons[3]!); // dispatch is the fourth card

    const dialog = await screen.findByRole('dialog', { name: strings.config.keys.dispatch });
    await user.click(within(dialog).getByRole('button', { name: strings.config.save }));

    expect(await screen.findByRole('alert')).toHaveTextContent(strings.config.saveError);
    updateSpy.mockRestore();
  });
});
