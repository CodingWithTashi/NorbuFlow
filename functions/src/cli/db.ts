// Database chores for the database named in `functions/.env`:
// `npm run db:migrate` and `npm run db:staff -- <temple-id> <email> <role>`.
import { openPostgres } from '../core/database';
import { setting } from '../core/environment';
import { migrate } from '../core/migrations';
import { type Role, roles } from '../features/temples/temple';

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);
  const database = await openPostgres(setting('DATABASE_URL'));
  try {
    if (command === 'migrate') {
      const applied = await migrate(database);
      console.log(applied.length ? `Applied: ${applied.join(', ')}` : 'Already up to date.');
    } else if (command === 'staff') {
      const [templeId, email, role] = args;
      if (!templeId || !email || !roles.includes(role as Role)) {
        throw new Error(`Usage: db:staff -- <temple-id> <email> <${roles.join('|')}>`);
      }
      await database.query(
        `insert into temple_staff (temple_id, email, role) values ($1, $2, $3)
         on conflict (temple_id, email) do update set role = excluded.role`,
        [templeId, email.trim().toLowerCase(), role],
      );
      console.log(`${email} is now ${role} at ${templeId}.`);
    } else {
      throw new Error('Commands: migrate, staff');
    }
  } finally {
    await database.close();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
