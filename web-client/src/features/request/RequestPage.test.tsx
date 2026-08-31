import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AppRoutes, AppShell } from '../../App';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { mockGeolocation } from '../../test/setup';

/** WEB-1 follow-up: quoting is public, so the request form is visible with
 * no sign-in step at all -- fills it in and fetches a quote. */
async function requestQuote(user: ReturnType<typeof userEvent.setup>) {
  await user.type(
    screen.getByLabelText(strings.request.pickupLabel),
    'Cra. 43A #1-50, El Poblado',
  );
  await user.type(screen.getByLabelText(strings.request.dropoffLabel), 'Cl. 10 #52-25, Guayabal');
  await user.click(screen.getByRole('radio', { name: strings.vehicleTypes.car }));
  await user.click(screen.getByRole('button', { name: strings.request.getQuote }));
  await screen.findByTestId('quote-price');
}

/** Clicks Confirm on a rendered quote, then signs in AND completes the
 * WEB-1 profile-completion gate (a fresh FakeAuth/MockApi identity always
 * has no name) -- both only appear once Confirm is pressed without a
 * usable identity yet, not up front. Booking proceeds automatically once
 * the profile is complete. */
async function confirmSigningIn(
  user: ReturnType<typeof userEvent.setup>,
  phone: string,
  name = 'Ana Gómez',
) {
  await user.click(screen.getByRole('button', { name: strings.request.confirm }));
  await user.type(await screen.findByLabelText(strings.auth.phoneLabel), phone);
  await user.click(screen.getByRole('button', { name: strings.auth.submit }));
  await user.type(await screen.findByLabelText(strings.auth.codeLabel), '123456');
  await user.click(screen.getByRole('button', { name: strings.auth.confirm }));
  await user.type(await screen.findByLabelText(strings.completeProfile.nameLabel), name);
  await user.click(screen.getByRole('button', { name: strings.completeProfile.saveButton }));
}

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
  it('quotes anonymously in COP, then signs in at confirm time and redirects to tracking', async () => {
    const user = userEvent.setup();
    renderApp();

    // WEB-1 follow-up: no sign-in needed to see the form or get a quote —
    // /v1/jobs/quote is public. The pickup field is visible immediately.
    expect(screen.getByLabelText(strings.request.pickupLabel)).toBeInTheDocument();
    await requestQuote(user);

    // Quote renders, formatted as es-CO COP.
    const price = screen.getByTestId('quote-price');
    const text = price.textContent ?? '';
    expect(text).toMatch(/^\$/);
    const amount = Number(text.replace(/[^\d]/g, ''));
    expect(amount).toBeGreaterThan(0);
    expect(text).toBe(formatCOP(amount)); // round-trips through Intl es-CO/COP

    // Confirm without an identity yet → sign-in, then profile completion,
    // appear inline; booking proceeds on its own once both are done.
    await confirmSigningIn(user, '3001234567');
    expect(
      await screen.findByRole('heading', { name: strings.tracking.title }),
    ).toBeInTheDocument();
  });

  it('keeps the quote button disabled until pickup, dropoff and vehicle type are set', async () => {
    const user = userEvent.setup();
    renderApp();

    const quoteBtn = screen.getByRole('button', { name: strings.request.getQuote });
    expect(quoteBtn).toBeDisabled();

    await user.type(screen.getByLabelText(strings.request.pickupLabel), 'A');
    await user.type(screen.getByLabelText(strings.request.dropoffLabel), 'B');
    expect(quoteBtn).toBeDisabled();

    await user.click(screen.getByRole('radio', { name: strings.vehicleTypes.moto }));
    expect(quoteBtn).toBeEnabled();
  });
});

describe('"usar mi ubicación actual" (WEB-2)', () => {
  it('fills the pickup field with the real GPS coordinates on success', async () => {
    mockGeolocation.getCurrentPosition.mockImplementation(
      (success: (pos: { coords: { latitude: number; longitude: number } }) => void) => {
        success({ coords: { latitude: 6.25184, longitude: -75.56359 } });
      },
    );
    const user = userEvent.setup();
    renderApp();

    await user.click(screen.getByRole('button', { name: strings.request.useCurrentLocation }));

    expect(await screen.findByLabelText(strings.request.pickupLabel)).toHaveValue(
      strings.request.locationText(6.25184, -75.56359),
    );
    expect(
      screen.queryByText(strings.request.locationUnavailable),
    ).not.toBeInTheDocument();
  });

  it('shows a message and leaves the field untouched when permission is denied', async () => {
    mockGeolocation.getCurrentPosition.mockImplementation(
      (
        _success: (pos: unknown) => void,
        error: (err: { code: number; message: string }) => void,
      ) => {
        error({ code: 1, message: 'User denied geolocation' });
      },
    );
    const user = userEvent.setup();
    renderApp();

    const pickupInput = screen.getByLabelText(strings.request.pickupLabel);
    await user.click(screen.getByRole('button', { name: strings.request.useCurrentLocation }));

    expect(await screen.findByText(strings.request.locationUnavailable)).toBeInTheDocument();
    expect(pickupInput).toHaveValue('');
  });

  it('lets the user override the GPS text by typing, which falls back to fakeGeocode', async () => {
    mockGeolocation.getCurrentPosition.mockImplementation(
      (success: (pos: { coords: { latitude: number; longitude: number } }) => void) => {
        success({ coords: { latitude: 6.25184, longitude: -75.56359 } });
      },
    );
    const user = userEvent.setup();
    renderApp();

    await user.click(screen.getByRole('button', { name: strings.request.useCurrentLocation }));
    const pickupInput = screen.getByLabelText(strings.request.pickupLabel);
    await user.clear(pickupInput);
    await user.type(pickupInput, 'Cra. 43A #1-50, El Poblado');

    expect(pickupInput).toHaveValue('Cra. 43A #1-50, El Poblado');
  });
});

describe('map (FND-6 follow-up)', () => {
  it('renders no pin until a real coordinate exists, then a pickup pin once GPS provides one', async () => {
    mockGeolocation.getCurrentPosition.mockImplementation(
      (success: (pos: { coords: { latitude: number; longitude: number } }) => void) => {
        success({ coords: { latitude: 6.25184, longitude: -75.56359 } });
      },
    );
    const user = userEvent.setup();
    renderApp();

    expect(screen.getByTestId('request-map')).toBeInTheDocument();
    // Neither pickup nor dropoff has a real coordinate yet (nothing typed,
    // no GPS fix taken) — RequestMap only renders a Marker once it has one.
    expect(screen.queryByTestId('map-marker')).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: strings.request.useCurrentLocation }));

    const marker = await screen.findByTestId('map-marker');
    expect(marker).toHaveAttribute('data-marker-label', 'A');
    expect(marker).toHaveAttribute('data-marker-lat', '6.25184');
    expect(marker).toHaveAttribute('data-marker-lng', '-75.56359');
  });

  it('shows the dashed placeholder instead when no Maps key is configured', async () => {
    vi.stubEnv('VITE_GOOGLE_MAPS_API_KEY', '');
    renderApp();

    expect(screen.getByText(`${strings.request.mapPlaceholder} — TODO(FND-6)`)).toBeInTheDocument();
    expect(screen.queryByTestId('request-map')).not.toBeInTheDocument();

    vi.unstubAllEnvs();
  });
});
