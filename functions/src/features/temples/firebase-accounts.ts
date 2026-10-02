import type { Accounts } from './accounts';

export class FirebaseAccounts implements Accounts {
  async ensure(email: string): Promise<void> {
    // Loaded on first use: only adding someone to a team needs it.
    const { getAuth } = await import('firebase-admin/auth');
    const auth = getAuth();
    try {
      await auth.getUserByEmail(email);
    } catch (error) {
      if ((error as { code?: string }).code !== 'auth/user-not-found') throw error;
      // No password: the only way in is a link sent to this address.
      await auth.createUser({ email });
    }
  }
}
