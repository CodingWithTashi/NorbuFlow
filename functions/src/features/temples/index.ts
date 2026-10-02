import { lazy } from '../../core/lazy';
import { database } from '../../runtime';
import { PostgresTempleRepository } from './postgres-temple.repository';
import { TempleAccess } from './temple-access';

export type { TempleAccess } from './temple-access';

/** Who may do what, on the deployed database. Every feature asks this one. */
export const templeAccess = lazy(
  async () => new TempleAccess(new PostgresTempleRepository(await database())),
);
