import type { ConfirmationResult, User } from 'firebase/auth';
import {
  RecaptchaVerifier,
  onAuthStateChanged,
  signInWithPhoneNumber,
  signOut,
} from 'firebase/auth';
import { firebaseAuth } from '../firebase';
import type { AuthClient, AuthUser, Unsubscribe } from './types';

function toAuthUser(user: User): AuthUser {
  return { uid: user.uid, phone: user.phoneNumber ?? '' };
}

/** Real phone-OTP sign-in via the Firebase web SDK — same accounts as the
 * mobile app. `signInWithPhoneNumber` requires an invisible reCAPTCHA bound
 * to a DOM node; we create our own container off-screen so callers (the
 * PhoneSignIn form) don't need to render anything special for it. */
export class FirebaseAuthClient implements AuthClient {
  private confirmationResult: ConfirmationResult | null = null;
  private verifier: RecaptchaVerifier | null = null;

  private getVerifier(): RecaptchaVerifier {
    if (this.verifier) return this.verifier;
    let container = document.getElementById('firebase-recaptcha-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'firebase-recaptcha-container';
      container.style.display = 'none';
      document.body.appendChild(container);
    }
    this.verifier = new RecaptchaVerifier(firebaseAuth, container, { size: 'invisible' });
    return this.verifier;
  }

  async getIdToken(): Promise<string | null> {
    const user = firebaseAuth.currentUser;
    return user ? user.getIdToken() : null;
  }

  async sendCode(phone: string): Promise<void> {
    this.confirmationResult = await signInWithPhoneNumber(firebaseAuth, phone, this.getVerifier());
  }

  async confirmCode(code: string): Promise<AuthUser> {
    if (!this.confirmationResult) {
      throw new Error('sendCode must be called before confirmCode');
    }
    const credential = await this.confirmationResult.confirm(code);
    this.confirmationResult = null;
    return toAuthUser(credential.user);
  }

  async signOut(): Promise<void> {
    await signOut(firebaseAuth);
  }

  getCurrentUser(): AuthUser | null {
    return firebaseAuth.currentUser ? toAuthUser(firebaseAuth.currentUser) : null;
  }

  onAuthStateChanged(cb: (user: AuthUser | null) => void): Unsubscribe {
    return onAuthStateChanged(firebaseAuth, (user) => cb(user ? toAuthUser(user) : null));
  }
}
