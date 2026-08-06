export interface AuthUser {
  uid: string;
  phone: string;
}

export type Unsubscribe = () => void;

/**
 * The auth seam. FakeAuth (one-step, dev-only) and FirebaseAuthClient (real
 * phone OTP) both implement this two-step shape: `sendCode` triggers the SMS
 * (or, for the fake, does nothing but succeed), `confirmCode` completes
 * sign-in against whatever `sendCode` most recently started. No handle is
 * threaded between the two calls — each implementation holds its own
 * in-flight verification state internally (mirrors the Firebase JS SDK's own
 * `ConfirmationResult` model).
 */
export interface AuthClient {
  /** Current Firebase ID token (or fake token) — attached as Bearer by HttpApi. */
  getIdToken(): Promise<string | null>;
  /** Sends an OTP to `phone` (E.164, e.g. +573001234567). */
  sendCode(phone: string): Promise<void>;
  /** Confirms the code sent by the most recent `sendCode` call. */
  confirmCode(code: string): Promise<AuthUser>;
  signOut(): Promise<void>;
  getCurrentUser(): AuthUser | null;
  onAuthStateChanged(cb: (user: AuthUser | null) => void): Unsubscribe;
}
