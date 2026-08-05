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

function renderLedgerPage() {
  return render(
    <MemoryRouter
      initialEntries={['/ledger']}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('LedgerPage (ADM-6)', () => {
  it('recording a settlement reduces the driver balance shown in the table', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    const user = userEvent.setup();
    renderLedgerPage();

    // Jorge Salazar is seeded with the highest balance (165,000, over the cap)
    // and sorts first since the table sorts by balance descending.
    const row = (await screen.findByText('Jorge Salazar')).closest('tr') as HTMLElement;
    expect(within(row).getByText(cop(165000))).toBeInTheDocument();
    expect(within(row).getByText(strings.ledger.capped)).toBeInTheDocument();

    await user.click(within(row).getByRole('button', { name: strings.ledger.settle }));

    const dialog = await screen.findByRole('dialog', {
      name: `${strings.ledger.settleTitle} — Jorge Salazar`,
    });
    await user.type(within(dialog).getByLabelText(strings.ledger.amountLabel), '50000');
    await user.click(within(dialog).getByRole('button', { name: strings.ledger.confirm }));

    // Balance drops by the settled amount and the row is no longer capped.
    await within(row).findByText(cop(115000));
    expect(within(row).queryByText(strings.ledger.capped)).not.toBeInTheDocument();
  });
});
