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

function renderFleetsPage() {
  return render(
    <MemoryRouter
      initialEntries={['/fleets']}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('FleetsPage (ADM-7)', () => {
  it('lists seeded fleets with owner, truck count and consolidated balance', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    renderFleetsPage();

    // Flota Restrepo: drv_1 (45,000) + drv_3 (165,000) + drv_7 (12,000) = 222,000.
    const row = (await screen.findByText('Flota Restrepo')).closest('tr') as HTMLElement;
    expect(within(row).getByText('Ricardo Restrepo Holdings')).toBeInTheDocument();
    expect(within(row).getByText('3')).toBeInTheDocument();
    expect(within(row).getByText(cop(222000))).toBeInTheDocument();
  });

  it('drilling into a fleet shows the per-driver member balance breakdown', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderFleetsPage();

    const row = (await screen.findByText('Flota del Valle')).closest('tr') as HTMLElement;
    await user.click(row);

    const card = (await screen.findByText(/Flota del Valle$/, { selector: 'h2' })).closest(
      'div',
    ) as HTMLElement;
    // Andrea Muñoz (82,000) and Natalia Zapata (95,000) are fleet_2's members.
    expect(await within(card).findByText('Andrea Muñoz')).toBeInTheDocument();
    expect(within(card).getByText(cop(82000))).toBeInTheDocument();
    expect(within(card).getByText('Natalia Zapata')).toBeInTheDocument();
    expect(within(card).getByText(cop(95000))).toBeInTheDocument();
  });

  it('settling a fleet apportions the amount across member drivers and refreshes the balance', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderFleetsPage();

    const row = (await screen.findByText('Flota Restrepo')).closest('tr') as HTMLElement;
    await user.click(within(row).getByRole('button', { name: strings.fleets.settle }));

    const dialog = await screen.findByRole('dialog', {
      name: `${strings.fleets.settleTitle} — Flota Restrepo`,
    });
    await user.type(within(dialog).getByLabelText(strings.fleets.amountLabel), '22200');
    await user.click(within(dialog).getByRole('button', { name: strings.fleets.confirm }));

    // Confirmation shows the apportioned total plus a per-driver breakdown
    // summing back to it.
    const confirmDialog = await screen.findByRole('dialog', {
      name: `${strings.fleets.settleResultTitle} — Flota Restrepo`,
    });
    expect(within(confirmDialog).getByText(cop(22200))).toBeInTheDocument();

    await user.click(within(confirmDialog).getByRole('button', { name: strings.fleets.close }));

    // The list balance drops by the settled amount: 222,000 - 22,200 = 199,800.
    const updatedRow = (await screen.findByText('Flota Restrepo')).closest('tr') as HTMLElement;
    await within(updatedRow).findByText(cop(199800));
  });
});
