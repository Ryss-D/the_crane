import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { api } from '../api';
import { AuthContext } from './context';
import { authClient } from './singleton';
import type { AuthUser } from './types';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => authClient.getCurrentUser());
  // Tracks which uid we've already synced, so the effect below fires once
  // per sign-in transition (not on every render, and not again for the same
  // uid after a re-render caused by something unrelated).
  const syncedUidRef = useRef<string | null>(null);

  useEffect(() => authClient.onAuthStateChanged(setUser), []);

  useEffect(() => {
    if (!user) {
      // Reset so signing back in — even as the same uid — syncs again.
      syncedUidRef.current = null;
      return;
    }
    if (syncedUidRef.current === user.uid) return;
    syncedUidRef.current = user.uid;
    // AUTH-2: create-or-fetch the backend `users` row for this Firebase
    // account. Idempotent server-side, but we still only fire it once per
    // sign-in here — mirrors the Flutter app's AuthCubit._afterSignIn().
    // Without this, the customer's first authenticated call (e.g.
    // POST /v1/jobs/quote) 404s: get_current_user has no row to resolve.
    void api.syncAuth({ phone: user.phone }).catch(() => {
      // Best-effort — allow a retry on the next render of this same uid
      // (e.g. a transient network error) instead of getting stuck synced.
      if (syncedUidRef.current === user.uid) syncedUidRef.current = null;
    });
  }, [user]);

  const sendCode = useCallback((phone: string) => authClient.sendCode(phone), []);
  const confirmCode = useCallback((code: string) => authClient.confirmCode(code), []);
  const signOut = useCallback(() => authClient.signOut(), []);

  const value = useMemo(
    () => ({ user, sendCode, confirmCode, signOut }),
    [user, sendCode, confirmCode, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
