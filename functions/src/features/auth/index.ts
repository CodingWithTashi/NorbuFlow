import { defineCallable, definePublicCallable } from '../../core/callable';
import { lazy } from '../../core/lazy';
import { database } from '../../runtime';
import { templeAccess } from '../temples';
import { checkEmailInput } from './auth.input';
import { AuthService } from './auth.service';
import { PostgresUserRepository } from './postgres-user.repository';

const service = lazy(
  async () => new AuthService(new PostgresUserRepository(await database()), await templeAccess()),
);

/**
 * `auth-startSession`: called once, right after the app exchanges an email
 * link for a Firebase session.
 */
export const startSession = defineCallable({
  handler: async (caller) => {
    const auth = await service();
    return { user: await auth.startSession(caller) };
  },
});

/**
 * `auth-checkEmail`: whether an address may sign in, asked from the sign-in
 * screen before a link is sent. Open to anyone, and says only yes or no.
 */
export const checkEmail = definePublicCallable({
  input: checkEmailInput,
  handler: async ({ email }) => {
    const auth = await service();
    return { invited: await auth.isInvited(email) };
  },
});
