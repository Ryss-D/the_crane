import { useCallback, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { AuthContext } from './context';
import { authClient } from './singleton';
import type { AuthUser } from './types';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => authClient.getCurrentUser());

  useEffect(() => authClient.onAuthStateChanged(setUser), []);

  const signInWithPhone = useCallback((phone: string) => authClient.signInWithPhone(phone), []);
  const signOut = useCallback(() => authClient.signOut(), []);

  const value = useMemo(
    () => ({ user, signInWithPhone, signOut }),
    [user, signInWithPhone, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
