/** Runs one SQL statement: all that most repositories need. */
export interface Sql {
  query<Row>(sql: string, params?: unknown[]): Promise<Row[]>;
}

/**
 * The database: Neon (Postgres) when deployed. Queries cast `bigint` and
 * `date` columns to text, so rows look the same from every driver.
 */
export interface Database extends Sql {
  /** Runs `work` in one transaction: saved together, or not at all if it throws. */
  transaction<T>(work: (tx: Sql) => Promise<T>): Promise<T>;
  /** Runs a script of several statements. For migrations. */
  exec(sql: string): Promise<void>;
  close(): Promise<void>;
}

export async function openPostgres(connectionString: string): Promise<Database> {
  const { Pool } = await import('pg');
  // Small on purpose: instances multiply under load, and Neon's pooler does the rest.
  const pool = new Pool({ connectionString, max: 5, connectionTimeoutMillis: 10_000 });
  // A dropped connection fails its own queries. Unheard, the event would end the process.
  pool.on('error', (error) => console.warn('A database connection was lost.', error));
  pool.on('connect', (client) => client.on('error', () => undefined));

  return {
    query: async (sql, params) => (await pool.query(sql, params)).rows,
    exec: async (sql) => void (await pool.query(sql)),
    close: () => pool.end(),
    async transaction(work) {
      const client = await pool.connect();
      let unusable: Error | undefined;
      try {
        await client.query('begin');
        const result = await work({
          query: async (sql, params) => (await client.query(sql, params)).rows,
        });
        await client.query('commit');
        return result;
      } catch (error) {
        // `error` is the failure to report. A connection that cannot roll back is dropped.
        await client.query('rollback').catch((failure: Error) => (unusable = failure));
        throw error;
      } finally {
        client.release(unusable);
      }
    },
  };
}

/**
 * A real Postgres that lives in memory and is gone when the process ends.
 * What tests and the emulator run on, so neither needs Neon.
 */
export async function openInMemory(): Promise<Database> {
  const { PGlite } = await import('@electric-sql/pglite');
  const postgres = new PGlite();
  return {
    query: async <Row>(sql: string, params?: unknown[]) =>
      (await postgres.query<Row>(sql, params)).rows,
    exec: async (sql) => void (await postgres.exec(sql)),
    close: () => postgres.close(),
    transaction: (work) =>
      postgres.transaction((tx) =>
        work({
          query: async <Row>(sql: string, params?: unknown[]) =>
            (await tx.query<Row>(sql, params)).rows,
        }),
      ),
  };
}
