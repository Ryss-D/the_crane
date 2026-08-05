export interface AdminUser {
  uid: string;
  email: string;
  /** MVP: FakeAuth always grants 'admin'. Real backend enforces role=admin server-side too. */
  role: 'admin';
}

export type Unsubscribe = () => void;

/**
 * The auth seam. FakeAuth implements it today; the Firebase web SDK adapter
 * will implement the SAME interface later.
 *
 * TODO(FND-1): add `FirebaseAuthClient` (firebase/auth, email/password or
 * Google sign-in) once the Firebase project exists, and select it in
 * src/auth/singleton.ts when VITE_USE_MOCKS=false. The backend's admin router
 * additionally verifies `role=admin` on the resolved user row on every
 * request (ADM-2 AC) — the client-side gate here is a UX convenience only,
 * never the security boundary.
 */
export interface AuthClient {
  /** Current Firebase ID token (or fake token) — attached as Bearer by HttpApi. */
  getIdToken(): Promise<string | null>;
  /** Dev shape: any email/password combination signs in as an admin. */
  signInWithPassword(email: string, password: string): Promise<AdminUser>;
  signOut(): Promise<void>;
  getCurrentUser(): AdminUser | null;
  onAuthStateChanged(cb: (user: AdminUser | null) => void): Unsubscribe;
}
