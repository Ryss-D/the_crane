export interface AuthUser {
  uid: string;
  phone: string;
}

export type Unsubscribe = () => void;

/**
 * The auth seam. FakeAuth implements it today; the Firebase web SDK adapter
 * will implement the SAME interface later.
 *
 * TODO(FND-1): add `FirebaseAuthClient` (firebase/auth, phone OTP via
 * signInWithPhoneNumber + RecaptchaVerifier) once the Firebase project exists,
 * and select it in src/auth/index.ts when VITE_USE_MOCKS=false.
 */
export interface AuthClient {
  /** Current Firebase ID token (or fake token) — attached as Bearer by HttpApi. */
  getIdToken(): Promise<string | null>;
  /**
   * Dev shape: one-step. The real flow is two-step (send OTP → confirm code);
   * the interface grows a `confirmCode()` when FND-1 lands.
   */
  signInWithPhone(phone: string): Promise<AuthUser>;
  signOut(): Promise<void>;
  getCurrentUser(): AuthUser | null;
  onAuthStateChanged(cb: (user: AuthUser | null) => void): Unsubscribe;
}
