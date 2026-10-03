import type { Database, Sql } from '../../core/database';
import type {
  MembershipTerm,
  NewTemple,
  Role,
  Temple,
  TempleFeature,
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
  features: TempleFeature[];
}

const columns = `t.id, t.name, t.description, t.time_zone, t.card_template, t.membership_term,
                 t.membership_year_end_month, t.membership_year_end_day, t.membership_months,
                 t.logo_key,
                 array(select f.feature from temple_features f
                        where f.temple_id = t.id order by f.feature) as features`;

export class PostgresTempleRepository implements TempleRepository {
  constructor(private readonly database: Database) {}

  async rolesOf(email: string): Promise<TempleRole[]> {
    const rows = await this.database.query<Row & { role: Role }>(
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
    const [row] = await this.database.query<Row>(
      `select ${columns} from temples t where t.id = $1`,
      [id],
    );
    return row && templeOf(row);
  }

  async create(temple: NewTemple): Promise<boolean> {
    return this.database.transaction(async (tx) => {
      const added = await insertTemple(tx, temple);
      if (added) await insertFeatures(tx, temple.id, temple.features);
      return added;
    });
  }

  async setLogo(id: string, logoKey: string): Promise<void> {
    await this.database.query(`update temples set logo_key = $2 where id = $1`, [id, logoKey]);
  }

  async setFeatures(id: string, features: TempleFeature[]): Promise<void> {
    await this.database.transaction(async (tx) => {
      // The temple's lock: two lists sent at once must not merge.
      await tx.query(`select 1 from temples where id = $1 for update`, [id]);
      await tx.query(`delete from temple_features where temple_id = $1`, [id]);
      await insertFeatures(tx, id, features);
    });
  }

  async addStaff(templeId: string, email: string, role: Role): Promise<void> {
    await this.database.query(
      `insert into temple_staff (temple_id, email, role) values ($1, $2, $3)
       on conflict (temple_id, email) do update set role = excluded.role`,
      [templeId, email, role],
    );
  }
}

/** False, and nothing added, if a temple already has its id. */
async function insertTemple(tx: Sql, temple: NewTemple): Promise<boolean> {
  const term = temple.membershipTerm;
  const fixed = term.kind === 'fixedYearEnd' ? term : undefined;
  const added = await tx.query(
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

async function insertFeatures(tx: Sql, templeId: string, features: TempleFeature[]) {
  await tx.query(
    `insert into temple_features (temple_id, feature)
     select $1::text, unnest($2::text[])
     on conflict do nothing`,
    [templeId, features],
  );
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
    features: row.features,
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
