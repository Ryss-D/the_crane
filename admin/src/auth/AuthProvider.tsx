import { useCallback, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { AuthContext } from './context';
import { authClient } from './singleton';
import type { AdminUser } from './types';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(() => authClient.getCurrentUser());

  useEffect(() => authClient.onAuthStateChanged(setUser), []);

  const signInWithPassword = useCallback(
    (email: string, password: string) => authClient.signInWithPassword(email, password),
    [],
  );
  const signOut = useCallback(() => authClient.signOut(), []);

  const value = useMemo(
    () => ({ user, signInWithPassword, signOut }),
    [user, signInWithPassword, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
