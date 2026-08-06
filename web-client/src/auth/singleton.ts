import type { AuthClient } from './types';
import { FakeAuth } from './fakeAuth';
import { FirebaseAuthClient } from './firebaseAuth';

/** Auth seam singleton — FakeAuth by default (VITE_USE_MOCKS=true), the real
 * Firebase phone-OTP client once VITE_USE_MOCKS=false. */
export const authClient: AuthClient =
  import.meta.env.VITE_USE_MOCKS !== 'false' ? new FakeAuth() : new FirebaseAuthClient();
