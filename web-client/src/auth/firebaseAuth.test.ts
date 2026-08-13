import type { User } from 'firebase/auth';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * `firebaseAuth.ts` is the real Firebase phone-OTP client (used once
 * VITE_USE_MOCKS=false). We mock the `firebase/auth` module entirely so its
 * send-code/confirm-code/sign-out logic and error propagation get exercised
 * without touching a real Firebase project or reCAPTCHA.
 *
 * `getAuth` must still return something, since `../firebase` calls it at
 * module-eval time (`export const firebaseAuth = getAuth(firebaseApp)`), and
 * that same object is what `firebaseAuth.ts` reads `.currentUser` off of —
 * so tests mutate it directly to simulate signed-in/signed-out state.
 *
 * `src/test/setup.ts` already imports `../auth/singleton` (which pulls in
 * `../firebase` and this module) before any test file's `vi.mock` hoisting
 * can run, so those modules are cached with the *real* Firebase SDK by the
 * time this file's body starts. `vi.resetModules()` + dynamic imports (per
 * `src/api/index.test.ts`'s established convention for this exact seam)
 * force a fresh evaluation that actually picks up the mock.
 */
vi.mock('firebase/auth', () => ({
  getAuth: vi.fn(() => ({ currentUser: null })),
  RecaptchaVerifier: vi.fn(),
  onAuthStateChanged: vi.fn(),
  signInWithPhoneNumber: vi.fn(),
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

  afterEach(() => {
    document.getElementById('firebase-recaptcha-container')?.remove();
  });

  describe('sendCode / getVerifier', () => {
    it('creates a single hidden reCAPTCHA container and reuses it across calls', async () => {
      vi.mocked(auth.signInWithPhoneNumber).mockResolvedValue({
        confirm: vi.fn(),
      } as unknown as Awaited<ReturnType<typeof auth.signInWithPhoneNumber>>);
      const client = new FirebaseAuthClient();

      await client.sendCode('+573001234567');

      expect(auth.RecaptchaVerifier).toHaveBeenCalledTimes(1);
      const container = document.getElementById('firebase-recaptcha-container');
      expect(container).not.toBeNull();
      expect(container?.style.display).toBe('none');
      expect(vi.mocked(auth.RecaptchaVerifier).mock.calls[0]).toEqual([
        firebaseAuth,
        container,
        { size: 'invisible' },
      ]);

      await client.sendCode('+573009998888');

      // Cached on the instance — no second verifier/container created.
      expect(auth.RecaptchaVerifier).toHaveBeenCalledTimes(1);
      expect(document.querySelectorAll('#firebase-recaptcha-container')).toHaveLength(1);
    });

    it('calls signInWithPhoneNumber with the phone number and the verifier', async () => {
      vi.mocked(auth.signInWithPhoneNumber).mockResolvedValue({
        confirm: vi.fn(),
      } as unknown as Awaited<ReturnType<typeof auth.signInWithPhoneNumber>>);
      const client = new FirebaseAuthClient();

      await client.sendCode('+573001234567');

      expect(auth.signInWithPhoneNumber).toHaveBeenCalledWith(
        firebaseAuth,
        '+573001234567',
        expect.anything(),
      );
    });

    it('propagates a sendCode failure and leaves no pending confirmation behind', async () => {
      const err = new Error('too-many-requests');
      vi.mocked(auth.signInWithPhoneNumber).mockRejectedValue(err);
      const client = new FirebaseAuthClient();

      await expect(client.sendCode('+573001234567')).rejects.toThrow('too-many-requests');
      await expect(client.confirmCode('123456')).rejects.toThrow(
        'sendCode must be called before confirmCode',
      );
    });
  });

  describe('confirmCode', () => {
    it('throws when called before sendCode', async () => {
      const client = new FirebaseAuthClient();
      await expect(client.confirmCode('123456')).rejects.toThrow(
        'sendCode must be called before confirmCode',
      );
    });

    it('confirms the pending verification and maps the Firebase user to AuthUser', async () => {
      const confirm = vi
        .fn()
        .mockResolvedValue({ user: { uid: 'abc123', phoneNumber: '+573001234567' } });
      vi.mocked(auth.signInWithPhoneNumber).mockResolvedValue({
        confirm,
      } as unknown as Awaited<ReturnType<typeof auth.signInWithPhoneNumber>>);
      const client = new FirebaseAuthClient();
      await client.sendCode('+573001234567');

      const user = await client.confirmCode('000000');

      expect(confirm).toHaveBeenCalledWith('000000');
      expect(user).toEqual({ uid: 'abc123', phone: '+573001234567' });
    });

    it('maps a null phoneNumber to an empty string', async () => {
      const confirm = vi.fn().mockResolvedValue({ user: { uid: 'abc123', phoneNumber: null } });
      vi.mocked(auth.signInWithPhoneNumber).mockResolvedValue({
        confirm,
      } as unknown as Awaited<ReturnType<typeof auth.signInWithPhoneNumber>>);
      const client = new FirebaseAuthClient();
      await client.sendCode('+573001234567');

      const user = await client.confirmCode('000000');

      expect(user.phone).toBe('');
    });

    it('clears the pending confirmation after a successful confirm, so a second call fails', async () => {
      const confirm = vi
        .fn()
        .mockResolvedValue({ user: { uid: 'abc123', phoneNumber: '+573001234567' } });
      vi.mocked(auth.signInWithPhoneNumber).mockResolvedValue({
        confirm,
      } as unknown as Awaited<ReturnType<typeof auth.signInWithPhoneNumber>>);
      const client = new FirebaseAuthClient();
      await client.sendCode('+573001234567');
      await client.confirmCode('000000');

      await expect(client.confirmCode('111111')).rejects.toThrow(
        'sendCode must be called before confirmCode',
      );
    });

    it('keeps the pending confirmation available for retry when confirm() rejects (e.g. wrong code)', async () => {
      const confirm = vi
        .fn()
        .mockRejectedValueOnce(new Error('invalid-verification-code'))
        .mockResolvedValueOnce({ user: { uid: 'abc123', phoneNumber: '+573001234567' } });
      vi.mocked(auth.signInWithPhoneNumber).mockResolvedValue({
        confirm,
      } as unknown as Awaited<ReturnType<typeof auth.signInWithPhoneNumber>>);
      const client = new FirebaseAuthClient();
      await client.sendCode('+573001234567');

      await expect(client.confirmCode('000000')).rejects.toThrow('invalid-verification-code');
      // Same confirmationResult is still there — retry with the right code succeeds.
      await expect(client.confirmCode('111111')).resolves.toEqual({
        uid: 'abc123',
        phone: '+573001234567',
      });
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
      setCurrentUser({ uid: 'u1', phoneNumber: '+573001234567' } as unknown as User);
      const client = new FirebaseAuthClient();
      expect(client.getCurrentUser()).toEqual({ uid: 'u1', phone: '+573001234567' });
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
      setCurrentUser({ uid: 'u1', phoneNumber: null, getIdToken } as unknown as User);
      const client = new FirebaseAuthClient();

      await expect(client.getIdToken()).resolves.toBe('tok-123');
      expect(getIdToken).toHaveBeenCalled();
    });
  });

  describe('onAuthStateChanged', () => {
    it('subscribes to the SDK and maps emitted users through toAuthUser', () => {
      let capturedCb: ((user: User | null) => void) | undefined;
      vi.mocked(auth.onAuthStateChanged).mockImplementation((_auth, cb) => {
        capturedCb = cb as (user: User | null) => void;
        return vi.fn();
      });
      const client = new FirebaseAuthClient();
      const listener = vi.fn();

      client.onAuthStateChanged(listener);

      expect(auth.onAuthStateChanged).toHaveBeenCalledWith(firebaseAuth, expect.any(Function));

      capturedCb?.({ uid: 'u2', phoneNumber: '+573009998888' } as unknown as User);
      expect(listener).toHaveBeenCalledWith({ uid: 'u2', phone: '+573009998888' });

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
