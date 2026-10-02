import { parseIsoDate, toIsoDate } from '../../core/calendar-date';
import type { Database } from '../../core/database';
import type { IssuedCardRecord, Member, MemberRepository, NewMember } from './member';

interface FoundRow {
  number: string;
  name: string;
  email: string | null;
  phone: string | null;
  joined_on: string;
  renewed_on: string;
  expires_on: string;
  pdf_key: string;
}

export class PostgresMemberRepository implements MemberRepository {
  constructor(private readonly database: Database) {}

  async find(
    templeId: string,
    id: string,
  ): Promise<{ member: Member; pdfKey: string } | undefined> {
    // The latest card carries the number as the temple writes it.
    const [row] = await this.database.query<FoundRow>(
      `select c.number, m.name, m.email, m.phone,
              m.joined_on::text, m.renewed_on::text, m.expires_on::text, c.pdf_key
         from members m
         join member_cards c on c.temple_id = m.temple_id and c.member_id = m.id
        where m.temple_id = $1 and m.id = $2
        order by c.issued_at desc
        limit 1`,
      [templeId, id],
    );
    if (!row) return undefined;
    return {
      pdfKey: row.pdf_key,
      member: {
        id,
        templeId,
        number: row.number,
        name: row.name,
        email: row.email,
        phone: row.phone,
        joinedOn: parseIsoDate(row.joined_on),
        renewedOn: parseIsoDate(row.renewed_on),
        expiresOn: parseIsoDate(row.expires_on),
      },
    };
  }

  async create<Card extends IssuedCardRecord>(
    member: NewMember,
    issueCard: (number: string) => Promise<Card>,
  ): Promise<{ member: Member; card: Card }> {
    return this.database.transaction(async (tx) => {
      // Updating the temple's row makes concurrent callers wait their turn, so
      // numbers never repeat. `label` is the number as the temple writes it.
      const [taken] = await tx.query<{ number: string; label: string }>(
        `with taken as (
           update temples set member_number_next = member_number_next + 1
            where id = $1
            returning member_number_next - 1 as number,
                      member_number_prefix as prefix,
                      member_number_min_digits as min_digits
         )
         select number::text,
                prefix || lpad(number::text, greatest(min_digits, length(number::text)), '0')
                  as label
           from taken`,
        [member.templeId],
      );
      if (!taken) throw new Error(`No temple with id "${member.templeId}".`);

      const card = await issueCard(taken.label);
      const renewedOn = toIsoDate(member.renewedOn);
      const expiresOn = toIsoDate(member.expiresOn);

      await tx.query(
        `insert into members
           (id, temple_id, number, name, email, phone, photo_key,
            joined_on, renewed_on, expires_on, created_by)
         values ($1, $2, $3, $4, $5, $6, $7, $8::date, $9::date, $10::date, $11)`,
        [
          member.id,
          member.templeId,
          taken.number,
          member.name,
          member.email,
          member.phone,
          member.photoKey,
          toIsoDate(member.joinedOn),
          renewedOn,
          expiresOn,
          member.createdBy,
        ],
      );
      await tx.query(
        `insert into member_cards
           (id, temple_id, member_id, number, name, valid_from, valid_until,
            template, photo_key, pdf_key, issued_by)
         values ($1, $2, $3, $4, $5, $6::date, $7::date, $8, $9, $10, $11)`,
        [
          card.id,
          member.templeId,
          member.id,
          taken.label,
          member.name,
          renewedOn,
          expiresOn,
          card.template,
          card.photoKey,
          card.pdfKey,
          member.createdBy,
        ],
      );

      return {
        card,
        member: {
          id: member.id,
          templeId: member.templeId,
          number: taken.label,
          name: member.name,
          email: member.email,
          phone: member.phone,
          joinedOn: member.joinedOn,
          renewedOn: member.renewedOn,
          expiresOn: member.expiresOn,
        },
      };
    });
  }
}
