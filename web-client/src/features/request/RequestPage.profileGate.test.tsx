import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import type * as authModule from '../../auth';
import type { AuthContextValue } from '../../auth';
import type { UserProfile } from '../../api/types';
import { strings } from '../../i18n/strings';
import { RequestPage } from './RequestPage';

/**
 * WEB-1 follow-up: quoting is public now (see backend's create_quote
 * docstring), so RequestPage no longer gates page load on `user`/`profile`
 * at all — it renders the form unconditionally and only reaches for
 * PhoneSignIn/CompleteProfileForm once Confirm is pressed without a usable
 * identity yet. Mocking `useAuth` directly (rather than driving the real
 * AuthProvider/MockApi singleton, see RequestPage.test.tsx for that
 * integration coverage) lets each case assert its own exact user/profile
 * shape in isolation.
 */
const mockUseAuth = vi.fn<() => AuthContextValue>();

vi.mock('../../auth', async () => {
  const actual = await vi.importActual<typeof authModule>('../../auth');
  return { ...actual, useAuth: () => mockUseAuth() };
});

function profile(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: 'usr_1',
    firebase_uid: 'fb_1',
    role: 'customer',
    name: null,
    phone: '+573001234567',
    email: null,
    fcm_token: null,
    created_at: new Date().toISOString(),
    ...overrides,
  };
}

function authValue(overrides: Partial<AuthContextValue> = {}): AuthContextValue {
  return {
    user: null,
    profile: null,
    sendCode: vi.fn(),
    confirmCode: vi.fn(),
    signOut: vi.fn(),
    completeProfile: vi.fn(),
    ...overrides,
  };
}

function renderPage() {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <RequestPage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

/** Fills the form and fetches a quote so a Confirm button exists to press. */
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

describe('RequestPage auth-at-confirm gate (WEB-1 follow-up)', () => {
  it('renders the request form immediately with no user and no profile at all', () => {
    mockUseAuth.mockReturnValue(authValue({ user: null, profile: null }));
    renderPage();

    expect(screen.getByLabelText(strings.request.pickupLabel)).toBeInTheDocument();
    expect(screen.queryByText(strings.auth.title)).not.toBeInTheDocument();
    expect(screen.queryByText(strings.completeProfile.title)).not.toBeInTheDocument();
  });

  it('shows phone sign-in only after Confirm is pressed with no user signed in', async () => {
    mockUseAuth.mockReturnValue(authValue({ user: null, profile: null }));
    const user = userEvent.setup();
    renderPage();
    await requestQuote(user);

    expect(screen.queryByText(strings.auth.title)).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: strings.request.confirm }));

    expect(await screen.findByText(strings.auth.title)).toBeInTheDocument();
  });

  it('shows the completion form after Confirm when signed in but the synced profile has no name', async () => {
    mockUseAuth.mockReturnValue(
      authValue({ user: { uid: 'fb_1', phone: '+573001234567' }, profile: profile({ name: null }) }),
    );
    const user = userEvent.setup();
    renderPage();
    await requestQuote(user);

    expect(screen.queryByText(strings.completeProfile.title)).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: strings.request.confirm }));

    expect(await screen.findByText(strings.completeProfile.title)).toBeInTheDocument();
  });

  it('submitting the completion form calls completeProfile with the entered name', async () => {
    const completeProfile = vi.fn().mockResolvedValue(undefined);
    mockUseAuth.mockReturnValue(
      authValue({
        user: { uid: 'fb_1', phone: '+573001234567' },
        profile: profile({ name: null }),
        completeProfile,
      }),
    );
    const user = userEvent.setup();
    renderPage();
    await requestQuote(user);
    await user.click(screen.getByRole('button', { name: strings.request.confirm }));

    await user.type(
      await screen.findByLabelText(strings.completeProfile.nameLabel),
      'Ana Gómez',
    );
    await user.click(screen.getByRole('button', { name: strings.completeProfile.saveButton }));

    expect(completeProfile).toHaveBeenCalledWith('Ana Gómez');
  });

  it('shows an error and re-enables the completion form if completeProfile fails', async () => {
    const completeProfile = vi.fn().mockRejectedValue(new Error('network'));
    mockUseAuth.mockReturnValue(
      authValue({
        user: { uid: 'fb_1', phone: '+573001234567' },
        profile: profile({ name: null }),
        completeProfile,
      }),
    );
    const user = userEvent.setup();
    renderPage();
    await requestQuote(user);
    await user.click(screen.getByRole('button', { name: strings.request.confirm }));

    await user.type(
      await screen.findByLabelText(strings.completeProfile.nameLabel),
      'Ana Gómez',
    );
    const saveButton = screen.getByRole('button', { name: strings.completeProfile.saveButton });
    await user.click(saveButton);

    expect(await screen.findByText(strings.completeProfile.saveError)).toBeInTheDocument();
    expect(saveButton).toBeEnabled();
  });

  it('skips the gate entirely and books straight through when the profile already has a name', async () => {
    mockUseAuth.mockReturnValue(
      authValue({
        user: { uid: 'fb_1', phone: '+573001234567' },
        profile: profile({ name: 'Ana Gómez' }),
      }),
    );
    const user = userEvent.setup();
    renderPage();
    await requestQuote(user);
    await user.click(screen.getByRole('button', { name: strings.request.confirm }));

    expect(screen.queryByText(strings.auth.title)).not.toBeInTheDocument();
    expect(screen.queryByText(strings.completeProfile.title)).not.toBeInTheDocument();
  });
});
