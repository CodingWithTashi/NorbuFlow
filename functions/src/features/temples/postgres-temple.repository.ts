import type { Sql } from '../../core/database';
import type {
  MembershipTerm,
  NewTemple,
  Role,
  Temple,
  TempleRepository,
  TempleRole,
} from './temple';

interface Row {
  id: string;
  name: string;
  description: string;
  time_zone: string;
  card_template: string;
  membership_term: 'fixed_year_end' | 'rolling';
  membership_year_end_month: number | null;
  membership_year_end_day: number | null;
  membership_months: number | null;
  logo_key: string | null;
}

const columns = `t.id, t.name, t.description, t.time_zone, t.card_template, t.membership_term,
                 t.membership_year_end_month, t.membership_year_end_day, t.membership_months,
                 t.logo_key`;

export class PostgresTempleRepository implements TempleRepository {
  constructor(private readonly sql: Sql) {}

  async rolesOf(email: string): Promise<TempleRole[]> {
    const rows = await this.sql.query<Row & { role: Role }>(
      `select ${columns}, s.role
         from temple_staff s
         join temples t on t.id = s.temple_id
        where s.email = $1
        order by t.name`,
      [email],
    );
    return rows.map((row) => ({ role: row.role, temple: templeOf(row) }));
  }

  async find(id: string): Promise<Temple | undefined> {
    const [row] = await this.sql.query<Row>(`select ${columns} from temples t where t.id = $1`, [
      id,
    ]);
    return row && templeOf(row);
  }

  async create(temple: NewTemple): Promise<boolean> {
    const term = temple.membershipTerm;
    const fixed = term.kind === 'fixedYearEnd' ? term : undefined;
    const added = await this.sql.query(
      `insert into temples
         (id, name, description, time_zone, card_template, membership_term,
          membership_year_end_month, membership_year_end_day, membership_months,
          member_number_next, member_number_prefix, member_number_min_digits)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
       on conflict (id) do nothing
       returning id`,
      [
        temple.id,
        temple.name,
        temple.description,
        temple.timeZone,
        temple.cardTemplate,
        fixed ? 'fixed_year_end' : 'rolling',
        fixed?.month ?? null,
        fixed?.day ?? null,
        term.kind === 'rolling' ? term.months : null,
        temple.memberNumber.next,
        temple.memberNumber.prefix,
        temple.memberNumber.minDigits,
      ],
    );
    return added.length > 0;
  }

  async setLogo(id: string, logoKey: string): Promise<void> {
    await this.sql.query(`update temples set logo_key = $2 where id = $1`, [id, logoKey]);
  }

  async addStaff(templeId: string, email: string, role: Role): Promise<void> {
    await this.sql.query(
      `insert into temple_staff (temple_id, email, role) values ($1, $2, $3)
       on conflict (temple_id, email) do update set role = excluded.role`,
      [templeId, email, role],
    );
  }
}

function templeOf(row: Row): Temple {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    timeZone: row.time_zone,
    cardTemplate: row.card_template,
    membershipTerm: termOf(row),
    logoKey: row.logo_key,
  };
}

// The table's check constraint guarantees the columns each kind needs.
function termOf(row: Row): MembershipTerm {
  return row.membership_term === 'rolling'
    ? { kind: 'rolling', months: row.membership_months! }
    : {
        kind: 'fixedYearEnd',
        month: row.membership_year_end_month!,
        day: row.membership_year_end_day!,
      };
}
