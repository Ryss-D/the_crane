import type { User } from 'firebase/auth';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { firebaseAuth } from '../firebase';
import type { AdminUser, AuthClient, Unsubscribe } from './types';

function toAdminUser(user: User): AdminUser {
  // Client-side "role" is a UX convenience only — the backend independently
  // enforces role=admin on every /v1/admin/* request (ADM-2's AC) regardless
  // of what this client believes.
  return { uid: user.uid, email: user.email ?? '', role: 'admin' };
}

/** Real email/password sign-in via the Firebase web SDK. Admin accounts are
 * created directly in the Firebase console (Authentication → Users) — there
 * is no self-service signup for this internal tool. */
export class FirebaseAuthClient implements AuthClient {
  async getIdToken(): Promise<string | null> {
    const user = firebaseAuth.currentUser;
    return user ? user.getIdToken() : null;
  }

  async signInWithPassword(email: string, password: string): Promise<AdminUser> {
    const credential = await signInWithEmailAndPassword(firebaseAuth, email, password);
    return toAdminUser(credential.user);
  }

  async signOut(): Promise<void> {
    await signOut(firebaseAuth);
  }

  getCurrentUser(): AdminUser | null {
    return firebaseAuth.currentUser ? toAdminUser(firebaseAuth.currentUser) : null;
  }

  onAuthStateChanged(cb: (user: AdminUser | null) => void): Unsubscribe {
    return onAuthStateChanged(firebaseAuth, (user) => cb(user ? toAdminUser(user) : null));
  }
}
