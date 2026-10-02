import { type Database, openInMemory } from '../../src/core/database';
import { migrate } from '../../src/core/migrations';

/** The temple the migrations create. */
export const loseling = 'drepung-loseling-canada';

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
