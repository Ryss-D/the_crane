import { createContext } from 'react';
import type { UserProfile } from '../api/types';
import type { AuthUser } from './types';

export interface AuthContextValue {
  user: AuthUser | null;
  /**
   * The backend-synced profile (AUTH-2's `POST /v1/auth/sync`), null until
   * that sync resolves. `profile.name === null` is the WEB-1 profile-
   * completion gate's trigger — mirrors the Flutter app's
   * `AuthPhase.needsProfile`.
   */
  profile: UserProfile | null;
  sendCode: (phone: string) => Promise<void>;
  confirmCode: (code: string) => Promise<AuthUser>;
  signOut: () => Promise<void>;
  /** `PATCH /v1/me` with the given name; updates [profile] on success. */
  completeProfile: (name: string) => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | null>(null);
