import type { Caller } from '../../core/caller';
import type { TempleAccess } from '../temples';
import { displayNameFromEmail } from './display-name';
import type { User, UserRepository } from './user';

/** Sign-in rules. Knows nothing about HTTP, Firebase or the database. */
export class AuthService {
  constructor(
    private readonly users: UserRepository,
    private readonly access: TempleAccess,
  ) {}

  /**
   * Whether `email` may sign in, asked before a link is sent so that nobody
   * waits for an email that cannot let them in.
   */
  isInvited(email: string): Promise<boolean> {
    return this.access.isOnATeam(email);
  }

  /**
   * Opens the caller's session and returns their profile, creating it on first
   * sign-in. Invite-only: some temple must have that email on its team.
   */
  async startSession(caller: Caller): Promise<User> {
    await this.access.rolesOf(caller);
    return this.users.ensure({
      id: caller.uid,
      email: caller.email,
      displayName: displayNameFromEmail(caller.email),
    });
  }
}
