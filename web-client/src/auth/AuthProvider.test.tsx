import { useState } from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { api } from '../api';
import { AuthProvider } from './AuthProvider';
import { useAuth } from './useAuth';

/** Exercises the AuthProvider through the public auth seam (sendCode /
 * confirmCode / signOut) rather than the request-flow UI, since the thing
 * under test — when syncAuth() fires — lives entirely inside the provider,
 * not any page. */
function Consumer() {
  const { user, sendCode, confirmCode, signOut } = useAuth();
  return (
    <div>
      <div data-testid="uid">{user?.uid ?? 'signed-out'}</div>
      <button onClick={() => void sendCode('3001234567').then(() => confirmCode('123456'))}>
        sign-in-a
      </button>
      <button onClick={() => void sendCode('3009998888').then(() => confirmCode('654321'))}>
        sign-in-b
      </button>
      <button onClick={() => void signOut()}>sign-out</button>
    </div>
  );
}

/** Wraps AuthProvider in a component with its own re-render trigger, so a
 * test can force AuthProvider's function body to re-run without any auth
 * state actually changing. */
function Harness() {
  const [n, setN] = useState(0);
  return (
    <div>
      <button onClick={() => setN((v) => v + 1)}>bump {n}</button>
      <AuthProvider>
        <Consumer />
      </AuthProvider>
    </div>
  );
}

describe('AuthProvider auth-sync (WEB-1 fix)', () => {
  it('calls syncAuth once on sign-in and not again on unrelated re-renders', async () => {
    const spy = vi.spyOn(api, 'syncAuth');
    const user = userEvent.setup();
    render(<Harness />);

    expect(spy).not.toHaveBeenCalled();

    await user.click(screen.getByRole('button', { name: 'sign-in-a' }));
    await waitFor(() => expect(screen.getByTestId('uid')).toHaveTextContent('fake-3001234567'));
    await waitFor(() => expect(spy).toHaveBeenCalledTimes(1));
    expect(spy).toHaveBeenCalledWith({ phone: '3001234567' });

    // Forcing the provider to re-render (parent state change, no auth
    // change) must not fire another sync for the same uid.
    await user.click(screen.getByRole('button', { name: /bump/ }));
    await user.click(screen.getByRole('button', { name: /bump/ }));
    expect(spy).toHaveBeenCalledTimes(1);
  });

  it('syncs again after sign-out and a different sign-in', async () => {
    const spy = vi.spyOn(api, 'syncAuth');
    const user = userEvent.setup();
    render(<Harness />);

    await user.click(screen.getByRole('button', { name: 'sign-in-a' }));
    await waitFor(() => expect(spy).toHaveBeenCalledTimes(1));

    await user.click(screen.getByRole('button', { name: 'sign-out' }));
    await waitFor(() => expect(screen.getByTestId('uid')).toHaveTextContent('signed-out'));

    await user.click(screen.getByRole('button', { name: 'sign-in-b' }));
    await waitFor(() => expect(screen.getByTestId('uid')).toHaveTextContent('fake-3009998888'));
    await waitFor(() => expect(spy).toHaveBeenCalledTimes(2));
    expect(spy).toHaveBeenLastCalledWith({ phone: '3009998888' });
  });
});
