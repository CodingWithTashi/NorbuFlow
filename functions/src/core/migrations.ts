import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

import { functionsFolder } from './assets';
import type { Database } from './database';

const folder = join(functionsFolder, 'migrations');

/** Applies the scripts in `functions/migrations` that have not run yet, in name order. */
export async function migrate(database: Database): Promise<string[]> {
  await database.exec(
    'create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())',
  );
  const done = new Set(
    (await database.query<{ name: string }>('select name from schema_migrations')).map(
      (row) => row.name,
    ),
  );
  const pending = readdirSync(folder)
    .filter((file) => file.endsWith('.sql') && !done.has(file))
    .sort();
  for (const file of pending) {
    const script = readFileSync(join(folder, file), 'utf8');
    // One transaction per script: it applies in full or not at all.
    await database.exec(
      `begin;\n${script}\n;insert into schema_migrations (name) values ('${file}');\ncommit;`,
    );
  }
  return pending;
}
