// Database chores for the database named in `functions/.env`:
// `npm run db:migrate`, `npm run db:staff -- <temple-id> <email> <role>` and
// `npm run db:import -- <temple-id> <email> <folder> [--check]`.
import { openPostgres } from '../core/database';
import { setting } from '../core/environment';
import { migrate } from '../core/migrations';
import { PostgresTempleRepository } from '../features/temples/postgres-temple.repository';
import { type Role, roles } from '../features/temples/temple';
import { fileStore } from '../runtime';
import { importMembers } from './import-members';

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
      const temples = new PostgresTempleRepository(database);
      await temples.addStaff(templeId, email.trim().toLowerCase(), role as Role);
      console.log(`${email} is now ${role} at ${templeId}.`);
    } else if (command === 'import') {
      const [templeId, email, folder, flag] = args;
      if (!templeId || !email || !folder || (flag && flag !== '--check')) {
        throw new Error('Usage: db:import -- <temple-id> <email> <folder> [--check]');
      }
      await importMembers(database, await fileStore(), {
        templeId,
        email: email.trim().toLowerCase(),
        folder,
        check: flag === '--check',
      });
    } else {
      throw new Error('Commands: migrate, staff, import');
    }
  } finally {
    await database.close();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
