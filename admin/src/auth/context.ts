import { createContext } from 'react';
import type { AdminUser } from './types';

export interface AuthContextValue {
  user: AdminUser | null;
  signInWithPassword: (email: string, password: string) => Promise<AdminUser>;
  signOut: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | null>(null);
