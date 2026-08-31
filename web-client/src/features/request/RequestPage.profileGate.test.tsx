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
 * WEB-1 profile-completion gate, tested in isolation from the real
 * AuthProvider/MockApi singleton (see RequestPage.test.tsx for the full
 * sign-in-through-mocks integration coverage) — the singleton's `userProfile`
 * persists across `it()` blocks in the same file once synced, which would
 * make a "profile already has a name" case here order-dependent on whatever
 * earlier test last completed one. Mocking `useAuth` directly sidesteps that
 * entirely and lets each case assert its own exact profile shape.
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
    user: { uid: 'fb_1', phone: '+573001234567' },
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

describe('RequestPage profile-completion gate (WEB-1)', () => {
  it('renders nothing while the profile sync is still in flight', () => {
    mockUseAuth.mockReturnValue(authValue({ profile: null }));
    const { container } = renderPage();
    expect(container).toBeEmptyDOMElement();
  });

  it('shows the completion form when the synced profile has no name', async () => {
    mockUseAuth.mockReturnValue(authValue({ profile: profile({ name: null }) }));
    renderPage();

    expect(await screen.findByText(strings.completeProfile.title)).toBeInTheDocument();
    expect(screen.queryByLabelText(strings.request.pickupLabel)).not.toBeInTheDocument();
  });

  it('submitting the form calls completeProfile with the entered name', async () => {
    const completeProfile = vi.fn().mockResolvedValue(undefined);
    mockUseAuth.mockReturnValue(
      authValue({ profile: profile({ name: null }), completeProfile }),
    );
    const user = userEvent.setup();
    renderPage();

    await user.type(
      await screen.findByLabelText(strings.completeProfile.nameLabel),
      'Ana Gómez',
    );
    await user.click(screen.getByRole('button', { name: strings.completeProfile.saveButton }));

    expect(completeProfile).toHaveBeenCalledWith('Ana Gómez');
  });

  it('shows an error and re-enables the form if completeProfile fails', async () => {
    const completeProfile = vi.fn().mockRejectedValue(new Error('network'));
    mockUseAuth.mockReturnValue(
      authValue({ profile: profile({ name: null }), completeProfile }),
    );
    const user = userEvent.setup();
    renderPage();

    await user.type(
      await screen.findByLabelText(strings.completeProfile.nameLabel),
      'Ana Gómez',
    );
    const saveButton = screen.getByRole('button', { name: strings.completeProfile.saveButton });
    await user.click(saveButton);

    expect(await screen.findByText(strings.completeProfile.saveError)).toBeInTheDocument();
    expect(saveButton).toBeEnabled();
  });

  it('skips the gate entirely when the profile already has a name', () => {
    mockUseAuth.mockReturnValue(authValue({ profile: profile({ name: 'Ana Gómez' }) }));
    renderPage();

    expect(screen.queryByText(strings.completeProfile.title)).not.toBeInTheDocument();
    expect(screen.getByLabelText(strings.request.pickupLabel)).toBeInTheDocument();
  });
});
