import { parseIsoDate, toIsoDate } from '../../core/calendar-date';
import type { Database, Sql } from '../../core/database';
import {
  type AlreadyIssued,
  type FiledMember,
  type IssuedCardRecord,
  type Member,
  type MemberChange,
  type MemberNumber,
  type MemberRepository,
  type NewMember,
  type NumberFormat,
  type NumberTaken,
  writeNumber,
} from './member';

interface Row {
  id: string;
  temple_id: string;
  digits: string;
  name: string;
  email: string | null;
  phone: string | null;
  photo_key: string;
  card_id: string | null;
  joined_on: string;
  renewed_on: string;
  expires_on: string;
  prefix: string;
  min_digits: number;
}

// A member with the card they hold and the way their temple writes numbers.
const memberColumns = `m.id, m.temple_id, m.number::text as digits, m.name, m.email, m.phone,
                       m.photo_key, m.joined_on::text, m.renewed_on::text, m.expires_on::text,
                       t.member_number_prefix as prefix, t.member_number_min_digits as min_digits,
                       (select held.id from member_cards held
                         where held.temple_id = m.temple_id and held.member_id = m.id
                         order by held.issued_at desc limit 1) as card_id`;
const members = `members m join temples t on t.id = m.temple_id`;

/** A member's row with where the card they hold is kept. */
type FiledRow = Row & { pdf_key: string };

interface Numbering extends NumberFormat {
  /** The digits the temple hands out next. */
  next: string;
}

export class PostgresMemberRepository implements MemberRepository {
  constructor(private readonly database: Database) {}

  async list(templeId: string): Promise<Member[]> {
    const rows = await this.database.query<Row>(
      `select ${memberColumns} from ${members}
        where m.temple_id = $1
        order by m.created_at desc, m.number desc`,
      [templeId],
    );
    return rows.map(memberOf);
  }

  find(templeId: string, id: string): Promise<FiledMember | undefined> {
    return filed(this.database, templeId, id);
  }

  async numberFor(templeId: string, digits?: string): Promise<MemberNumber> {
    const numbering = await numberingOf(this.database, templeId);
    const number = digits ?? (await firstFree(this.database, templeId, numbering.next));
    return { digits: number, label: writeNumber(numbering, number) };
  }

  async save<Card extends IssuedCardRecord>(
    member: NewMember,
    number: { digits?: string; replace: boolean },
    issueCard: (number: string, memberId: string) => Promise<Card>,
  ): Promise<{ member: Member; card: Card } | NumberTaken | AlreadyIssued> {
    return this.database.transaction(async (tx) => {
      // Locking the temple's row makes concurrent callers wait their turn, so
      // numbers never repeat and a request sent twice is seen to be a repeat.
      const numbering = await numberingOf(tx, member.templeId, 'for update');
      const issued = await holderOfCard(tx, member.templeId, member.id);
      if (issued) return { issued };

      let digits = number.digits;
      let holder: Row | undefined;
      if (digits === undefined) {
        digits = await firstFree(tx, member.templeId, numbering.next);
        await tx.query(`update temples set member_number_next = $2::bigint + 1 where id = $1`, [
          member.templeId,
          digits,
        ]);
      } else {
        holder = await holderOf(tx, member.templeId, digits);
        if (holder && !number.replace) return { taken: memberOf(holder) };
      }

      const label = writeNumber(numbering, digits);
      const id = holder?.id ?? member.id;
      const card = await issueCard(label, id);
      const renewedOn = toIsoDate(member.renewedOn);
      const expiresOn = toIsoDate(member.expiresOn);

      if (holder) {
        await tx.query(
          `update members
              set name = $3, email = $4, phone = $5, photo_key = $6,
                  renewed_on = $7::date, expires_on = $8::date, updated_at = now()
            where temple_id = $1 and id = $2`,
          [
            member.templeId,
            id,
            member.name,
            member.email,
            member.phone,
            card.photoKey,
            renewedOn,
            expiresOn,
          ],
        );
      } else {
        await tx.query(
          `insert into members
             (id, temple_id, number, name, email, phone, photo_key,
              joined_on, renewed_on, expires_on, created_by)
           values ($1, $2, $3, $4, $5, $6, $7, $8::date, $9::date, $10::date, $11)`,
          [
            id,
            member.templeId,
            digits,
            member.name,
            member.email,
            member.phone,
            card.photoKey,
            toIsoDate(member.joinedOn),
            renewedOn,
            expiresOn,
            member.createdBy,
          ],
        );
      }
      await insertCard(tx, card, {
        templeId: member.templeId,
        memberId: id,
        number: label,
        name: member.name,
        validFrom: renewedOn,
        validUntil: expiresOn,
        issuedBy: member.createdBy,
      });

      return {
        card,
        member: {
          id,
          templeId: member.templeId,
          number: label,
          name: member.name,
          email: member.email,
          phone: member.phone,
          photoKey: card.photoKey,
          cardId: card.id,
          joinedOn: holder ? parseIsoDate(holder.joined_on) : member.joinedOn,
          renewedOn: member.renewedOn,
          expiresOn: member.expiresOn,
        },
      };
    });
  }

  async change<Card extends IssuedCardRecord>(
    change: MemberChange,
    reissue: (filed: FiledMember, number: string) => Promise<Card | undefined>,
  ): Promise<
    { member: Member; card?: Card; pdfKey: string } | NumberTaken | AlreadyIssued | undefined
  > {
    return this.database.transaction(async (tx) => {
      // The same lock as `save`, so a number cannot be given out twice.
      const numbering = await numberingOf(tx, change.templeId, 'for update');
      const issued = await holderOfCard(tx, change.templeId, change.cardId);
      if (issued) return { issued };

      const current = await filed(tx, change.templeId, change.memberId);
      if (!current) return undefined;

      const digits = change.number ?? current.digits;
      if (digits !== current.digits) {
        const holder = await holderOf(tx, change.templeId, digits);
        if (holder) return { taken: memberOf(holder) };
      }

      const label = writeNumber(numbering, digits);
      const card = await reissue(current, label);
      await tx.query(
        `update members
            set number = $3, name = $4, email = $5, phone = $6, photo_key = $7,
                updated_at = now()
          where temple_id = $1 and id = $2`,
        [
          change.templeId,
          change.memberId,
          digits,
          change.name,
          change.email,
          change.phone,
          card?.photoKey ?? current.member.photoKey,
        ],
      );
      if (card) {
        await insertCard(tx, card, {
          templeId: change.templeId,
          memberId: change.memberId,
          number: label,
          name: change.name,
          validFrom: toIsoDate(current.member.renewedOn),
          validUntil: toIsoDate(current.member.expiresOn),
          issuedBy: change.changedBy,
        });
      }

      return {
        card,
        pdfKey: card?.pdfKey ?? current.pdfKey,
        member: {
          ...current.member,
          number: label,
          name: change.name,
          email: change.email,
          phone: change.phone,
          photoKey: card?.photoKey ?? current.member.photoKey,
          cardId: card?.id ?? current.member.cardId,
        },
      };
    });
  }
}

async function numberingOf(sql: Sql, templeId: string, lock = ''): Promise<Numbering> {
  const [row] = await sql.query<{ next: string; prefix: string; min_digits: number }>(
    `select member_number_next::text as next, member_number_prefix as prefix,
            member_number_min_digits as min_digits
       from temples where id = $1 ${lock}`,
    [templeId],
  );
  if (!row) throw new Error(`No temple with id "${templeId}".`);
  return { next: row.next, prefix: row.prefix, minDigits: row.min_digits };
}

/** The first number at or after `from` that nobody holds: one may have been typed in. */
async function firstFree(sql: Sql, templeId: string, from: string): Promise<string> {
  let digits = BigInt(from);
  while (await holderOf(sql, templeId, String(digits))) digits += 1n;
  return String(digits);
}

async function holderOf(sql: Sql, templeId: string, digits: string): Promise<Row | undefined> {
  const [row] = await sql.query<Row>(
    `select ${memberColumns} from ${members} where m.temple_id = $1 and m.number = $2`,
    [templeId, digits],
  );
  return row;
}

async function filed(sql: Sql, templeId: string, id: string): Promise<FiledMember | undefined> {
  const [row] = await sql.query<FiledRow>(
    `select ${memberColumns}, c.pdf_key
       from ${members}
       join member_cards c on c.temple_id = m.temple_id and c.member_id = m.id
      where m.temple_id = $1 and m.id = $2
      order by c.issued_at desc
      limit 1`,
    [templeId, id],
  );
  return row && filedOf(row);
}

/** Who the card with this id was issued to, as they stand now. */
async function holderOfCard(
  sql: Sql,
  templeId: string,
  cardId: string,
): Promise<FiledMember | undefined> {
  const [row] = await sql.query<FiledRow>(
    `select ${memberColumns}, c.pdf_key
       from member_cards c
       join ${members} on m.temple_id = c.temple_id and m.id = c.member_id
      where c.temple_id = $1 and c.id = $2`,
    [templeId, cardId],
  );
  return row && filedOf(row);
}

interface CardEntry {
  templeId: string;
  memberId: string;
  number: string;
  name: string;
  validFrom: string;
  validUntil: string;
  issuedBy: string;
}

async function insertCard(sql: Sql, card: IssuedCardRecord, entry: CardEntry): Promise<void> {
  // The clock, not the transaction's start: the newest card is the last one
  // issued under the lock, whichever request began first.
  await sql.query(
    `insert into member_cards
       (id, temple_id, member_id, number, name, valid_from, valid_until,
        template, photo_key, pdf_key, issued_by, issued_at)
     values ($1, $2, $3, $4, $5, $6::date, $7::date, $8, $9, $10, $11, clock_timestamp())`,
    [
      card.id,
      entry.templeId,
      entry.memberId,
      entry.number,
      entry.name,
      entry.validFrom,
      entry.validUntil,
      card.template,
      card.photoKey,
      card.pdfKey,
      entry.issuedBy,
    ],
  );
}

function filedOf(row: FiledRow): FiledMember {
  return { member: memberOf(row), digits: row.digits, pdfKey: row.pdf_key };
}

function memberOf(row: Row): Member {
  return {
    id: row.id,
    templeId: row.temple_id,
    number: writeNumber({ prefix: row.prefix, minDigits: row.min_digits }, row.digits),
    name: row.name,
    email: row.email,
    phone: row.phone,
    photoKey: row.photo_key,
    cardId: row.card_id,
    joinedOn: parseIsoDate(row.joined_on),
    renewedOn: parseIsoDate(row.renewed_on),
    expiresOn: parseIsoDate(row.expires_on),
  };
}
