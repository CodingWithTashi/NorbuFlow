/** A person with an account. `id` is their Firebase Auth uid. */
export interface User {
  id: string;
  email: string;
  displayName: string;
}

export interface UserRepository {
  /**
   * Records a sign-in and returns the person's profile, creating it from
   * `draft` if this is their first. An existing name is kept.
   */
  ensure(draft: User): Promise<User>;
}
