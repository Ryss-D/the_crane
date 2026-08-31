import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { api } from '../api';
import type { UserProfile } from '../api/types';
import { AuthContext } from './context';
import { authClient } from './singleton';
import type { AuthUser } from './types';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => authClient.getCurrentUser());
  // WEB-1: the backend-synced profile — null until syncAuth() resolves (or
  // there's no signed-in user at all). Its `name` field drives the
  // profile-completion gate (see RequestPage).
  const [profile, setProfile] = useState<UserProfile | null>(null);
  // Tracks which uid we've already synced, so the effect below fires once
  // per sign-in transition (not on every render, and not again for the same
  // uid after a re-render caused by something unrelated).
  const syncedUidRef = useRef<string | null>(null);

  useEffect(() => authClient.onAuthStateChanged(setUser), []);

  useEffect(() => {
    if (!user) {
      // Reset so signing back in — even as the same uid — syncs again.
      syncedUidRef.current = null;
      setProfile(null);
      return;
    }
    if (syncedUidRef.current === user.uid) return;
    syncedUidRef.current = user.uid;
    // AUTH-2: create-or-fetch the backend `users` row for this Firebase
    // account. Idempotent server-side, but we still only fire it once per
    // sign-in here — mirrors the Flutter app's AuthCubit._afterSignIn().
    // Without this, the customer's first authenticated call (e.g.
    // POST /v1/jobs/quote) 404s: get_current_user has no row to resolve.
    api
      .syncAuth({ phone: user.phone })
      .then(setProfile)
      .catch(() => {
        // Best-effort — allow a retry on the next render of this same uid
        // (e.g. a transient network error) instead of getting stuck synced.
        if (syncedUidRef.current === user.uid) syncedUidRef.current = null;
      });
  }, [user]);

  const sendCode = useCallback((phone: string) => authClient.sendCode(phone), []);
  const confirmCode = useCallback((code: string) => authClient.confirmCode(code), []);
  const signOut = useCallback(() => authClient.signOut(), []);
  // WEB-1: profile completion — mirrors the Flutter app's
  // `AuthCubit.completeProfile`. No local optimistic update beyond what
  // `updateMe`'s own response gives back, same "trust the server's row"
  // convention `syncAuth` already follows here.
  const completeProfile = useCallback(async (name: string) => {
    const updated = await api.updateMe({ name });
    setProfile(updated);
  }, []);

  const value = useMemo(
    () => ({ user, profile, sendCode, confirmCode, signOut, completeProfile }),
    [user, profile, sendCode, confirmCode, signOut, completeProfile],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
