import { useCallback, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { AuthContext } from './context';
import { authClient } from './singleton';
import type { AuthUser } from './types';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(() => authClient.getCurrentUser());

  useEffect(() => authClient.onAuthStateChanged(setUser), []);

  const sendCode = useCallback((phone: string) => authClient.sendCode(phone), []);
  const confirmCode = useCallback((code: string) => authClient.confirmCode(code), []);
  const signOut = useCallback(() => authClient.signOut(), []);

  const value = useMemo(
    () => ({ user, sendCode, confirmCode, signOut }),
    [user, sendCode, confirmCode, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
