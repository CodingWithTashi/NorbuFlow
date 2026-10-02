import { defineAdminEndpoint } from '../../core/admin-endpoint';
import { defineCallable } from '../../core/callable';
import { lazy } from '../../core/lazy';
import { database, fileStore } from '../../runtime';
import { templeNameProblem } from '../cards';
import { FirebaseAccounts } from './firebase-accounts';
import { PostgresTempleRepository } from './postgres-temple.repository';
import type { Temple } from './temple';
import { TempleAccess } from './temple-access';
import { newTempleInput, templeAdminInput, templeLogoInput } from './temples.input';
import { TempleService } from './temples.service';

export type { TempleAccess } from './temple-access';

const repository = lazy(async () => new PostgresTempleRepository(await database()));

/** Who may do what, on the deployed database. Every feature asks this one. */
export const templeAccess = lazy(async () => new TempleAccess(await repository()));

const service = lazy(
  async () =>
    new TempleService(
      await repository(),
      await templeAccess(),
      await fileStore(),
      new FirebaseAccounts(),
      templeNameProblem,
    ),
);

/** A temple as the operator's terminal shows it. */
const registered = (temple: Temple) => ({
  id: temple.id,
  name: temple.name,
  description: temple.description,
  timeZone: temple.timeZone,
  cardTemplate: temple.cardTemplate,
  membership: temple.membershipTerm,
  hasLogo: temple.logoKey !== null,
});

/** `temples-create`: registers a temple. For the operator, not the app. */
export const create = defineAdminEndpoint({
  // Checking the name against the standard card loads its fonts.
  options: { memory: '512MiB' },
  input: newTempleInput,
  handler: async (input) => {
    const temples = await service();
    return { temple: registered(await temples.create(input)) };
  },
});

/** `temples-setLogo`: stores the image sent as the body as the temple's logo. */
export const setLogo = defineAdminEndpoint({
  options: { memory: '512MiB' },
  input: templeLogoInput,
  read: (request) => ({ templeId: request.query.templeId, logo: request.rawBody }),
  handler: async ({ templeId, logo }) => {
    const temples = await service();
    return { temple: registered(await temples.setLogo(templeId, logo)) };
  },
});

/** `temples-addAdmin`: assigns a temple to the person who will run it. */
export const addAdmin = defineAdminEndpoint({
  input: templeAdminInput,
  handler: async ({ templeId, email }) => {
    const temples = await service();
    const temple = await temples.addAdmin(templeId, email);
    return { temple: registered(temple), email, role: 'admin' };
  },
});

/** `temples-list`: the temples the caller works at, for "Choose your temple". */
export const list = defineCallable({
  handler: async (caller) => {
    const temples = await service();
    const listings = await temples.templesOf(caller);
    return {
      temples: listings.map(({ temple, role, logo }) => ({
        id: temple.id,
        name: temple.name,
        description: temple.description,
        role,
        logo: logo ? Buffer.from(logo).toString('base64') : null,
      })),
    };
  },
});
