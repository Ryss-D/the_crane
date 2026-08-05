import type { AdminUser, AuthClient, Unsubscribe } from './types';

const STORAGE_KEY = 'crane-admin.fakeAuth.user';

/**
 * Dev-only auth: any email/password combination logs you in as `role=admin`.
 * Persists to localStorage so refreshes keep the session. No real
 * credential check, no network.
 *
 * TODO(FND-1): replace selection with the Firebase web SDK implementation of
 * AuthClient once the Firebase project exists, and enforce role=admin against
 * the real user row (the backend already rejects non-admin tokens per ADM-2's
 * AC — this client stub just mirrors "logged in as admin" for UI dev).
 */
export class FakeAuth implements AuthClient {
  private user: AdminUser | null;
  private readonly listeners = new Set<(user: AdminUser | null) => void>();

  constructor() {
    this.user = this.restore();
  }

  private restore(): AdminUser | null {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      return raw ? (JSON.parse(raw) as AdminUser) : null;
    } catch {
      return null;
    }
  }

  private setUser(user: AdminUser | null): void {
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

  signInWithPassword(email: string): Promise<AdminUser> {
    const normalized = email.trim().toLowerCase();
    const user: AdminUser = { uid: `fake-${normalized}`, email: normalized, role: 'admin' };
    this.setUser(user);
    return Promise.resolve(user);
  }

  signOut(): Promise<void> {
    this.setUser(null);
    return Promise.resolve();
  }

  getCurrentUser(): AdminUser | null {
    return this.user;
  }

  onAuthStateChanged(cb: (user: AdminUser | null) => void): Unsubscribe {
    this.listeners.add(cb);
    return () => this.listeners.delete(cb);
  }
}
