import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AppShell, AppRoutes } from '../../App';
import { authClient } from '../../auth';
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

describe('LoginPage (ADM-0)', () => {
  it('keeps the submit button disabled until both email and password are filled', async () => {
    const user = userEvent.setup();
    renderApp();

    const submit = screen.getByRole('button', { name: strings.auth.submit });
    expect(submit).toBeDisabled();

    await user.type(screen.getByLabelText(strings.auth.emailLabel), 'admin@thecrane.local');
    expect(submit).toBeDisabled();

    await user.type(screen.getByLabelText(strings.auth.passwordLabel), 'anything');
    expect(submit).toBeEnabled();

    // Blanking either field re-disables it.
    await user.clear(screen.getByLabelText(strings.auth.emailLabel));
    expect(submit).toBeDisabled();
  });

  it('signs in with any email/password (FakeAuth) and lands in the app shell', async () => {
    const user = userEvent.setup();
    renderApp();

    await user.type(screen.getByLabelText(strings.auth.emailLabel), 'admin@thecrane.local');
    await user.type(screen.getByLabelText(strings.auth.passwordLabel), 'anything');
    await user.click(screen.getByRole('button', { name: strings.auth.submit }));

    // Redirected past the login form into the dashboard, inside AppLayout.
    expect(await screen.findByText(strings.dashboard.title)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: strings.auth.submit })).not.toBeInTheDocument();
    expect(screen.queryByLabelText(strings.auth.emailLabel)).not.toBeInTheDocument();
  });

  it('resets the busy state and stays on the login form when sign-in rejects', async () => {
    const user = userEvent.setup();
    const error = new Error('network down');

    // LoginPage's onSubmit (see LoginPage.tsx) has no catch — only a
    // try/finally that resets `busy` — so a rejection here surfaces as a
    // genuine unhandled promise rejection under the hood (onSubmit's own
    // returned promise, which React's event dispatch never awaits or
    // attaches a handler to). That's the real, current error "state": no
    // error message UI, just busy resetting and the form staying put. Swallow
    // that one expected rejection at the process level so pinning this gap
    // doesn't fail the wider test run.
    const originalEmit = process.emit.bind(process);
    process.emit = ((event: string, ...args: unknown[]) => {
      if (event === 'unhandledRejection' && args[0] === error) return true;
      return originalEmit(event as never, ...(args as never[]));
    }) as typeof process.emit;

    const spy = vi.spyOn(authClient, 'signInWithPassword').mockRejectedValueOnce(error);
    renderApp();

    try {
      await user.type(screen.getByLabelText(strings.auth.emailLabel), 'admin@thecrane.local');
      await user.type(screen.getByLabelText(strings.auth.passwordLabel), 'anything');
      const submit = screen.getByRole('button', { name: strings.auth.submit });
      await user.click(submit);

      await waitFor(() => expect(submit).toBeEnabled());
      expect(screen.getByLabelText(strings.auth.emailLabel)).toBeInTheDocument();
      expect(screen.queryByText(strings.dashboard.title)).not.toBeInTheDocument();
    } finally {
      process.emit = originalEmit;
      spy.mockRestore();
    }
  });
});
