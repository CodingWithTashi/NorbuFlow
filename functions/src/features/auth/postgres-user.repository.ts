import type { Sql } from '../../core/database';
import type { User, UserRepository } from './user';

interface Row {
  id: string;
  email: string;
  display_name: string;
}

export class PostgresUserRepository implements UserRepository {
  constructor(private readonly sql: Sql) {}

  async ensure(draft: User): Promise<User> {
    // The email follows the Firebase account; the name, once set, is theirs.
    const [row] = await this.sql.query<Row>(
      `insert into users (id, email, display_name) values ($1, $2, $3)
       on conflict (id) do update set email = excluded.email, last_sign_in_at = now()
       returning id, email, display_name`,
      [draft.id, draft.email, draft.displayName],
    );
    return { id: row!.id, email: row!.email, displayName: row!.display_name };
  }
}
