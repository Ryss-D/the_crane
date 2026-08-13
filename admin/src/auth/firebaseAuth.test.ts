import type { User } from 'firebase/auth';
import { beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * `firebaseAuth.ts` is the real Firebase email/password admin client (used
 * once VITE_USE_MOCKS=false). We mock the `firebase/auth` module entirely so
 * its sign-in/sign-out/current-user logic and error propagation get
 * exercised without touching a real Firebase project.
 *
 * `getAuth` must still return something, since `../firebase` calls it at
 * module-eval time (`export const firebaseAuth = getAuth(firebaseApp)`), and
 * that same object is what `firebaseAuth.ts` reads `.currentUser` off of —
 * so tests mutate it directly to simulate signed-in/signed-out state.
 *
 * `src/test/setup.ts` already imports `../auth/singleton` (which imports
 * both FakeAuth and FirebaseAuthClient unconditionally, pulling in
 * `../firebase` and this module) before any test file's `vi.mock` hoisting
 * can run, so those modules are cached with the *real* Firebase SDK by the
 * time this file's body starts. `vi.resetModules()` + dynamic imports (per
 * web-client's established convention for this exact seam) force a fresh
 * evaluation that actually picks up the mock.
 */
vi.mock('firebase/auth', () => ({
  getAuth: vi.fn(() => ({ currentUser: null })),
  signInWithEmailAndPassword: vi.fn(),
  onAuthStateChanged: vi.fn(),
  signOut: vi.fn(),
}));

describe('FirebaseAuthClient', () => {
  let auth: typeof import('firebase/auth');
  let firebaseAuth: import('firebase/auth').Auth;
  let FirebaseAuthClient: typeof import('./firebaseAuth').FirebaseAuthClient;

  function setCurrentUser(user: User | null): void {
    (firebaseAuth as unknown as { currentUser: User | null }).currentUser = user;
  }

  beforeEach(async () => {
    vi.resetModules();
    auth = await import('firebase/auth');
    ({ firebaseAuth } = await import('../firebase'));
    ({ FirebaseAuthClient } = await import('./firebaseAuth'));
  });

  describe('signInWithPassword', () => {
    it('signs in via the SDK and maps the Firebase user to an AdminUser', async () => {
      vi.mocked(auth.signInWithEmailAndPassword).mockResolvedValue({
        user: { uid: 'abc123', email: 'admin@thecrane.local' },
      } as unknown as Awaited<ReturnType<typeof auth.signInWithEmailAndPassword>>);
      const client = new FirebaseAuthClient();

      const user = await client.signInWithPassword('admin@thecrane.local', 's3cret');

      expect(auth.signInWithEmailAndPassword).toHaveBeenCalledWith(
        firebaseAuth,
        'admin@thecrane.local',
        's3cret',
      );
      expect(user).toEqual({ uid: 'abc123', email: 'admin@thecrane.local', role: 'admin' });
    });

    it('maps a null email to an empty string', async () => {
      vi.mocked(auth.signInWithEmailAndPassword).mockResolvedValue({
        user: { uid: 'abc123', email: null },
      } as unknown as Awaited<ReturnType<typeof auth.signInWithEmailAndPassword>>);
      const client = new FirebaseAuthClient();

      const user = await client.signInWithPassword('admin@thecrane.local', 's3cret');

      expect(user.email).toBe('');
    });

    it('propagates a sign-in failure (e.g. wrong password)', async () => {
      const err = new Error('auth/wrong-password');
      vi.mocked(auth.signInWithEmailAndPassword).mockRejectedValue(err);
      const client = new FirebaseAuthClient();

      await expect(client.signInWithPassword('admin@thecrane.local', 'bad')).rejects.toThrow(
        'auth/wrong-password',
      );
    });
  });

  describe('signOut', () => {
    it('delegates to the Firebase SDK with the shared auth instance', async () => {
      const client = new FirebaseAuthClient();
      await client.signOut();
      expect(auth.signOut).toHaveBeenCalledWith(firebaseAuth);
    });
  });

  describe('getCurrentUser', () => {
    it('returns null when signed out', () => {
      setCurrentUser(null);
      const client = new FirebaseAuthClient();
      expect(client.getCurrentUser()).toBeNull();
    });

    it('maps the current Firebase user when signed in', () => {
      setCurrentUser({ uid: 'u1', email: 'admin@thecrane.local' } as unknown as User);
      const client = new FirebaseAuthClient();
      expect(client.getCurrentUser()).toEqual({
        uid: 'u1',
        email: 'admin@thecrane.local',
        role: 'admin',
      });
    });
  });

  describe('getIdToken', () => {
    it('returns null when signed out', async () => {
      setCurrentUser(null);
      const client = new FirebaseAuthClient();
      await expect(client.getIdToken()).resolves.toBeNull();
    });

    it("returns the current user's token when signed in", async () => {
      const getIdToken = vi.fn().mockResolvedValue('tok-123');
      setCurrentUser({ uid: 'u1', email: null, getIdToken } as unknown as User);
      const client = new FirebaseAuthClient();

      await expect(client.getIdToken()).resolves.toBe('tok-123');
      expect(getIdToken).toHaveBeenCalled();
    });
  });

  describe('onAuthStateChanged', () => {
    it('subscribes to the SDK and maps emitted users through toAdminUser', () => {
      let capturedCb: ((user: User | null) => void) | undefined;
      vi.mocked(auth.onAuthStateChanged).mockImplementation((_auth, cb) => {
        capturedCb = cb as (user: User | null) => void;
        return vi.fn();
      });
      const client = new FirebaseAuthClient();
      const listener = vi.fn();

      client.onAuthStateChanged(listener);

      expect(auth.onAuthStateChanged).toHaveBeenCalledWith(firebaseAuth, expect.any(Function));

      capturedCb?.({ uid: 'u2', email: 'other@thecrane.local' } as unknown as User);
      expect(listener).toHaveBeenCalledWith({
        uid: 'u2',
        email: 'other@thecrane.local',
        role: 'admin',
      });

      capturedCb?.(null);
      expect(listener).toHaveBeenCalledWith(null);
    });

    it("returns the SDK's unsubscribe function", () => {
      const unsub = vi.fn();
      vi.mocked(auth.onAuthStateChanged).mockReturnValue(unsub);
      const client = new FirebaseAuthClient();

      expect(client.onAuthStateChanged(vi.fn())).toBe(unsub);
    });
  });
});
