import type { Sql } from '../../core/database';
import type { MembershipTerm, Role, TempleRepository, TempleRole } from './temple';

interface Row {
  id: string;
  name: string;
  time_zone: string;
  card_template: string;
  membership_term: 'fixed_year_end' | 'rolling';
  membership_year_end_month: number | null;
  membership_year_end_day: number | null;
  membership_months: number | null;
  role: Role;
}

export class PostgresTempleRepository implements TempleRepository {
  constructor(private readonly sql: Sql) {}

  async rolesOf(email: string): Promise<TempleRole[]> {
    const rows = await this.sql.query<Row>(
      `select t.id, t.name, t.time_zone, t.card_template, t.membership_term,
              t.membership_year_end_month, t.membership_year_end_day, t.membership_months,
              s.role
         from temple_staff s
         join temples t on t.id = s.temple_id
        where s.email = $1
        order by t.name`,
      [email],
    );
    return rows.map((row) => ({
      role: row.role,
      temple: {
        id: row.id,
        name: row.name,
        timeZone: row.time_zone,
        cardTemplate: row.card_template,
        membershipTerm: termOf(row),
      },
    }));
  }
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
