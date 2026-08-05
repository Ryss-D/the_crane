import type { AuthClient } from './types';
import { FakeAuth } from './fakeAuth';

/**
 * Auth seam singleton.
 *
 * TODO(FND-1): when the Firebase project exists, instantiate the Firebase
 * implementation here when VITE_USE_MOCKS=false:
 *
 *   export const authClient: AuthClient =
 *     import.meta.env.VITE_USE_MOCKS !== 'false' ? new FakeAuth() : new FirebaseAuthClient();
 */
export const authClient: AuthClient = new FakeAuth();
