/** The accounts people sign in to (Firebase Authentication). */
export interface Accounts {
  /** Makes sure `email` has an account, creating it if this is the first time. */
  ensure(email: string): Promise<void>;
}
