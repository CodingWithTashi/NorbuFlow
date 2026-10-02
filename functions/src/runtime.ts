import { type Database, openInMemory, openPostgres } from './core/database';
import { setting, standIns } from './core/environment';
import { type FileStore, InMemoryFileStore, openR2 } from './core/file-store';
import { lazy } from './core/lazy';
import { migrate } from './core/migrations';

/** The database the functions use: Neon, or an in-memory stand-in. */
export const database = lazy(async (): Promise<Database> => {
  if (!standIns) return openPostgres(setting('DATABASE_URL'));

  const local = await openInMemory();
  await migrate(local);
  // A new database has nobody on a team, so nobody could sign in to it.
  const staff = process.env.LOCAL_STAFF_EMAIL?.trim().toLowerCase();
  if (staff) {
    await local.query(
      `insert into temple_staff (temple_id, email, role) select id, $1, 'admin' from temples`,
      [staff],
    );
  }
  return local;
});

/** Where the functions keep files: Cloudflare R2, or an in-memory stand-in. */
export const fileStore = lazy(async (): Promise<FileStore> =>
  standIns
    ? new InMemoryFileStore()
    : openR2({
        endpoint: setting('R2_ENDPOINT'),
        bucket: setting('R2_BUCKET'),
        accessKeyId: setting('R2_ACCESS_KEY_ID'),
        secretAccessKey: setting('R2_SECRET_ACCESS_KEY'),
      }),
);
