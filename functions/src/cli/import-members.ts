// `npm run db:import`: adds the members of a temple's hand-made cards, each
// with the card NorbuFlow prints from that card's number, name, photo and dates.
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

import { z } from 'zod';

import { parseIsoDate } from '../core/calendar-date';
import type { Caller } from '../core/caller';
import type { Database } from '../core/database';
import type { FileStore } from '../core/file-store';
import { cardRenderer } from '../features/cards';
import { newMemberInput } from '../features/members/members.input';
import { MemberService } from '../features/members/members.service';
import { PostgresMemberRepository } from '../features/members/postgres-member.repository';
import { PostgresTempleRepository } from '../features/temples/postgres-temple.repository';
import { TempleAccess } from '../features/temples/temple-access';

const date = z.iso.date().transform(parseIsoDate);

// `manifest.json`: one row per card. `id` is the card's, kept between runs so a
// second run repeats nothing; `photo` is a file beside the manifest.
const manifest = z.array(
  z.object({
    id: newMemberInput.shape.id,
    name: newMemberInput.shape.name,
    number: newMemberInput.shape.number.unwrap(),
    photo: z.string().min(1),
    joinedOn: date,
    renewedOn: date,
    expiresOn: date,
  }),
);

export interface ImportOptions {
  templeId: string;
  /** An admin or front desk of the temple, who has signed in: the cards' issuer. */
  email: string;
  folder: string;
  /** Saves nothing: draws every card into `<folder>/check` and says what a run would do. */
  check: boolean;
}

export async function importMembers(
  database: Database,
  files: FileStore,
  { templeId, email, folder, check }: ImportOptions,
): Promise<void> {
  const rows = manifest.parse(JSON.parse(await readFile(join(folder, 'manifest.json'), 'utf8')));
  const service = new MemberService(
    new TempleAccess(new PostgresTempleRepository(database)),
    new PostgresMemberRepository(database),
    files,
    cardRenderer,
    () => new Date(),
  );
  const caller: Caller = { uid: await uidOf(database, email), email };

  const held = new Map(
    (await service.list(caller, templeId)).map((member) => [member.number, member]),
  );
  if (check) await mkdir(join(folder, 'check'), { recursive: true });

  for (const row of rows) {
    const photo = await readFile(join(folder, row.photo));
    const request = { id: row.id, name: row.name, number: row.number, photo, templeId };
    const said = `${row.number} ${row.name}:`;

    if (check) {
      const { number, pdf } = await service.preview(caller, {
        ...request,
        validUntil: row.expiresOn,
      });
      await writeFile(join(folder, 'check', `${row.number}.pdf`), pdf);
      const holder = held.get(number.label);
      if (!holder) console.log(`${said} would be added`);
      else if (holder.cardId === row.id) console.log(`${said} already added`);
      else console.log(`${said} TAKEN by ${holder.name}`);
      continue;
    }

    const result = await service.addExisting(caller, request, row);
    if ('taken' in result) throw new Error(`${said} the number is ${result.taken.name}'s.`);
    console.log(`${said} on file`);
  }
}

/** The Firebase uid of the person signed in as `email`, whom the cards name as issuer. */
async function uidOf(database: Database, email: string): Promise<string> {
  const [user] = await database.query<{ id: string }>(
    `select id from users where email = $1 order by last_sign_in_at desc limit 1`,
    [email],
  );
  if (!user) throw new Error(`${email} has never signed in to the app.`);
  return user.id;
}
