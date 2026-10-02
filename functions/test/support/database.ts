import { type Database, openInMemory } from '../../src/core/database';
import { migrate } from '../../src/core/migrations';

/** The temple the migrations create. */
export const loseling = 'drepung-loseling-canada';

/** What its card is made from: a design of its own, so no logo is needed. */
export const loselingCard = {
  id: loseling,
  name: 'Drepung Loseling Canada',
  cardTemplate: loseling,
  logoKey: null,
};

/** An in-memory database with the schema applied. The caller closes it. */
export async function freshDatabase(): Promise<Database> {
  const database = await openInMemory();
  await migrate(database);
  return database;
}

export async function addToTeam(
  database: Database,
  email: string,
  role: string,
  templeId = loseling,
): Promise<void> {
  await database.query('insert into temple_staff (temple_id, email, role) values ($1, $2, $3)', [
    templeId,
    email,
    role,
  ]);
}
