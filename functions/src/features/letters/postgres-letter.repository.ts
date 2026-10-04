import { parseIsoDate, toIsoDate } from '../../core/calendar-date';
import type { Database, Sql } from '../../core/database';
import type {
  AlreadyIssued,
  FiledLetter,
  Letter,
  LetterBody,
  LetterRepository,
  NewLetter,
  NumberTaken,
} from './letter';

interface Row {
  id: string;
  temple_id: string;
  number: string;
  name: string;
  member_id: string | null;
  valid_until: string;
  issued_on: string;
}

const columns = `l.id, l.temple_id, l.number::text as number, l.name, l.member_id,
                 l.valid_until::text, l.issued_on::text`;

/** A letter's row with what it says and where its PDF is kept. */
type FiledRow = Row & { body: string; pdf_key: string };

export class PostgresLetterRepository implements LetterRepository {
  constructor(private readonly database: Database) {}

  async list(templeId: string): Promise<Letter[]> {
    const rows = await this.database.query<Row>(
      `select ${columns} from letters l
        where l.temple_id = $1
        order by l.issued_at desc, l.number desc`,
      [templeId],
    );
    return rows.map(letterOf);
  }

  find(templeId: string, id: string): Promise<FiledLetter | undefined> {
    return filed(this.database, templeId, id);
  }

  async isMember(templeId: string, memberId: string): Promise<boolean> {
    const found = await this.database.query(
      `select 1 from members where temple_id = $1 and id = $2`,
      [templeId, memberId],
    );
    return found.length > 0;
  }

  async numberFor(templeId: string, digits?: string): Promise<string> {
    return digits ?? firstFree(this.database, templeId, await nextNumber(this.database, templeId));
  }

  async save(
    letter: NewLetter,
    typed: string | undefined,
    file: (number: string) => Promise<{ pdfKey: string; pdf: Uint8Array }>,
  ): Promise<{ letter: Letter; pdf: Uint8Array } | NumberTaken | AlreadyIssued> {
    return this.database.transaction(async (tx) => {
      // Locking the temple's row makes concurrent callers wait their turn, so
      // numbers never repeat and a request sent twice is seen to be a repeat.
      const next = await nextNumber(tx, letter.templeId, 'for update');
      const issued = await filed(tx, letter.templeId, letter.id);
      if (issued) return { issued };

      let digits = typed;
      if (digits === undefined) {
        digits = await firstFree(tx, letter.templeId, next);
        await tx.query(`update temples set letter_number_next = $2::bigint + 1 where id = $1`, [
          letter.templeId,
          digits,
        ]);
      } else {
        const holder = await holderOf(tx, letter.templeId, digits);
        if (holder) return { taken: letterOf(holder) };
      }

      const { pdfKey, pdf } = await file(digits);
      // The clock, not the transaction's start: the newest letter is the last
      // one issued under the lock, whichever request began first.
      await tx.query(
        `insert into letters
           (id, temple_id, number, name, member_id, valid_until, issued_on, body,
            template, pdf_key, issued_by, issued_at)
         values ($1, $2, $3, $4, $5, $6::date, $7::date, $8::jsonb, $9, $10, $11,
                 clock_timestamp())`,
        [
          letter.id,
          letter.templeId,
          digits,
          letter.name,
          letter.memberId,
          toIsoDate(letter.validUntil),
          toIsoDate(letter.issuedOn),
          JSON.stringify(letter.body),
          letter.template,
          pdfKey,
          letter.issuedBy,
        ],
      );

      return {
        pdf,
        letter: {
          id: letter.id,
          templeId: letter.templeId,
          number: digits,
          name: letter.name,
          memberId: letter.memberId,
          validUntil: letter.validUntil,
          issuedOn: letter.issuedOn,
        },
      };
    });
  }
}

/** The digits the temple hands out next. */
async function nextNumber(sql: Sql, templeId: string, lock = ''): Promise<string> {
  const [row] = await sql.query<{ next: string }>(
    `select letter_number_next::text as next from temples where id = $1 ${lock}`,
    [templeId],
  );
  if (!row) throw new Error(`No temple with id "${templeId}".`);
  return row.next;
}

/** The first number at or after `from` that no letter carries: one may have been typed in. */
async function firstFree(sql: Sql, templeId: string, from: string): Promise<string> {
  let digits = BigInt(from);
  while (await holderOf(sql, templeId, String(digits))) digits += 1n;
  return String(digits);
}

async function holderOf(sql: Sql, templeId: string, digits: string): Promise<Row | undefined> {
  const [row] = await sql.query<Row>(
    `select ${columns} from letters l where l.temple_id = $1 and l.number = $2`,
    [templeId, digits],
  );
  return row;
}

async function filed(sql: Sql, templeId: string, id: string): Promise<FiledLetter | undefined> {
  // The body as text, so that it reads the same from every driver.
  const [row] = await sql.query<FiledRow>(
    `select ${columns}, l.body::text as body, l.pdf_key
       from letters l where l.temple_id = $1 and l.id = $2`,
    [templeId, id],
  );
  return (
    row && { letter: letterOf(row), body: JSON.parse(row.body) as LetterBody, pdfKey: row.pdf_key }
  );
}

function letterOf(row: Row): Letter {
  return {
    id: row.id,
    templeId: row.temple_id,
    number: row.number,
    name: row.name,
    memberId: row.member_id,
    validUntil: parseIsoDate(row.valid_until),
    issuedOn: parseIsoDate(row.issued_on),
  };
}
