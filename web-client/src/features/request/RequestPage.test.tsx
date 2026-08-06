import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { AppRoutes, AppShell } from '../../App';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';

function renderApp() {
  return render(
    <MemoryRouter
      initialEntries={['/']}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

describe('request flow (WEB-2 skeleton)', () => {
  it('signs in with any phone, quotes in COP, confirms and redirects to tracking', async () => {
    const user = userEvent.setup();
    renderApp();

    // FakeAuth gate: any phone + any code → logged in.
    await user.type(screen.getByLabelText(strings.auth.phoneLabel), '3001234567');
    await user.click(screen.getByRole('button', { name: strings.auth.submit }));
    await user.type(await screen.findByLabelText(strings.auth.codeLabel), '123456');
    await user.click(screen.getByRole('button', { name: strings.auth.confirm }));

    // Request form.
    await user.type(
      await screen.findByLabelText(strings.request.pickupLabel),
      'Cra. 43A #1-50, El Poblado',
    );
    await user.type(screen.getByLabelText(strings.request.dropoffLabel), 'Cl. 10 #52-25, Guayabal');
    await user.click(screen.getByRole('radio', { name: strings.vehicleTypes.car }));
    await user.click(screen.getByRole('button', { name: strings.request.getQuote }));

    // Quote renders, formatted as es-CO COP.
    const price = await screen.findByTestId('quote-price');
    const text = price.textContent ?? '';
    expect(text).toMatch(/^\$/);
    const amount = Number(text.replace(/[^\d]/g, ''));
    expect(amount).toBeGreaterThan(0);
    expect(text).toBe(formatCOP(amount)); // round-trips through Intl es-CO/COP

    // Confirm → mock job created → redirected to /jobs/:id (tracking page).
    await user.click(screen.getByRole('button', { name: strings.request.confirm }));
    expect(
      await screen.findByRole('heading', { name: strings.tracking.title }),
    ).toBeInTheDocument();
  });

  it('keeps the quote button disabled until pickup, dropoff and vehicle type are set', async () => {
    const user = userEvent.setup();
    renderApp();

    await user.type(screen.getByLabelText(strings.auth.phoneLabel), '3000000000');
    await user.click(screen.getByRole('button', { name: strings.auth.submit }));
    await user.type(await screen.findByLabelText(strings.auth.codeLabel), '123456');
    await user.click(screen.getByRole('button', { name: strings.auth.confirm }));

    const quoteBtn = await screen.findByRole('button', { name: strings.request.getQuote });
    expect(quoteBtn).toBeDisabled();

    await user.type(screen.getByLabelText(strings.request.pickupLabel), 'A');
    await user.type(screen.getByLabelText(strings.request.dropoffLabel), 'B');
    expect(quoteBtn).toBeDisabled();

    await user.click(screen.getByRole('radio', { name: strings.vehicleTypes.moto }));
    expect(quoteBtn).toBeEnabled();
  });
});
