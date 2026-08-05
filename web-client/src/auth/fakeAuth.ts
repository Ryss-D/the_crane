import type { AuthClient, AuthUser, Unsubscribe } from './types';

const STORAGE_KEY = 'crane.fakeAuth.user';

/**
 * Dev-only auth: enter any phone number → "logged in". Persists to
 * localStorage so refreshes keep the session. No OTP, no network.
 *
 * TODO(FND-1): replace selection with the Firebase web SDK implementation of
 * AuthClient once the Firebase project exists.
 */
export class FakeAuth implements AuthClient {
  private user: AuthUser | null;
  private readonly listeners = new Set<(user: AuthUser | null) => void>();

  constructor() {
    this.user = this.restore();
  }

  private restore(): AuthUser | null {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      return raw ? (JSON.parse(raw) as AuthUser) : null;
    } catch {
      return null;
    }
  }

  private setUser(user: AuthUser | null): void {
    this.user = user;
    try {
      if (user) window.localStorage.setItem(STORAGE_KEY, JSON.stringify(user));
      else window.localStorage.removeItem(STORAGE_KEY);
    } catch {
      // localStorage unavailable (private mode) — session-only auth is fine in dev.
    }
    this.listeners.forEach((cb) => cb(user));
  }

  getIdToken(): Promise<string | null> {
    return Promise.resolve(this.user ? `fake-id-token-${this.user.uid}` : null);
  }

  signInWithPhone(phone: string): Promise<AuthUser> {
    const normalized = phone.replace(/\s+/g, '');
    const user: AuthUser = { uid: `fake-${normalized}`, phone: normalized };
    this.setUser(user);
    return Promise.resolve(user);
  }

  signOut(): Promise<void> {
    this.setUser(null);
    return Promise.resolve();
  }

  getCurrentUser(): AuthUser | null {
    return this.user;
  }

  onAuthStateChanged(cb: (user: AuthUser | null) => void): Unsubscribe {
    this.listeners.add(cb);
    return () => this.listeners.delete(cb);
  }
}
