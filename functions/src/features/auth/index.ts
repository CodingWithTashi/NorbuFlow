import { defineCallable } from '../../core/callable';
import { lazy } from '../../core/lazy';
import { database } from '../../runtime';
import { templeAccess } from '../temples';
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
