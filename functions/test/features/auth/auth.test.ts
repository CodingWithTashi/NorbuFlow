import { beforeEach, describe, expect, it } from 'vitest';

import type { Database } from '../../../src/core/database';
import { parseInput } from '../../../src/core/validation';
import { checkEmailInput } from '../../../src/features/auth/auth.input';
import { AuthService } from '../../../src/features/auth/auth.service';
import { displayNameFromEmail } from '../../../src/features/auth/display-name';
import { PostgresUserRepository } from '../../../src/features/auth/postgres-user.repository';
import { PostgresTempleRepository } from '../../../src/features/temples/postgres-temple.repository';
import { TempleAccess } from '../../../src/features/temples/temple-access';
import { addToTeam, freshDatabase } from '../../support/database';

describe('starting a session', () => {
  const karma = { uid: 'uid-karma', email: 'karma.treasurer@gmail.com' };
  let database: Database;
  let auth: AuthService;

  beforeEach(async () => {
    database = await freshDatabase();
    await addToTeam(database, karma.email, 'accountant');
    auth = new AuthService(
      new PostgresUserRepository(database),
      new TempleAccess(new PostgresTempleRepository(database)),
    );
    return () => database.close();
  });

  it('names a first-time user after their email', async () => {
    await expect(auth.startSession(karma)).resolves.toEqual({
      id: 'uid-karma',
      email: 'karma.treasurer@gmail.com',
      displayName: 'Karma Treasurer',
    });
  });

  it('keeps the name a returning user already has', async () => {
    await auth.startSession(karma);
    await database.query(`update users set display_name = 'Karma Tsering' where id = $1`, [
      karma.uid,
    ]);

    const user = await auth.startSession(karma);

    expect(user.displayName).toBe('Karma Tsering');
  });

  it('keeps one profile per person, however often they sign in', async () => {
    await auth.startSession(karma);
    await auth.startSession(karma);

    const rows = await database.query(`select id from users`);
    expect(rows).toHaveLength(1);
  });

  it('follows the Firebase account when its email changes', async () => {
    await auth.startSession(karma);
    const moved = { uid: karma.uid, email: 'karma@loseling.example' };
    await addToTeam(database, moved.email, 'accountant');

    await expect(auth.startSession(moved)).resolves.toMatchObject({
      id: 'uid-karma',
      email: 'karma@loseling.example',
      displayName: 'Karma Treasurer',
    });
  });

  it('lets in an account that was deleted in Firebase and made again', async () => {
    await auth.startSession(karma);
    const remade = { uid: 'uid-karma-again', email: karma.email };

    await expect(auth.startSession(remade)).resolves.toMatchObject({
      id: 'uid-karma-again',
      email: karma.email,
    });
  });

  it('turns away a proven email that no temple has invited, and keeps no profile', async () => {
    const stranger = { uid: 'uid-stranger', email: 'stranger@example.org' };

    await expect(auth.startSession(stranger)).rejects.toMatchObject({
      kind: 'permissionDenied',
      details: { reason: 'notOnTeam' },
    });
    expect(await database.query(`select id from users`)).toHaveLength(0);
  });
});

describe('checking an email before sending a link', () => {
  let database: Database;
  let auth: AuthService;

  beforeEach(async () => {
    database = await freshDatabase();
    await addToTeam(database, 'karma.treasurer@gmail.com', 'accountant');
    auth = new AuthService(
      new PostgresUserRepository(database),
      new TempleAccess(new PostgresTempleRepository(database)),
    );
    return () => database.close();
  });

  it('says yes to an address a temple has added', async () => {
    await expect(auth.isInvited('karma.treasurer@gmail.com')).resolves.toBe(true);
  });

  it('says no to any other, and keeps nothing about it', async () => {
    await expect(auth.isInvited('stranger@example.org')).resolves.toBe(false);
    expect(await database.query(`select id from users`)).toHaveLength(0);
  });

  it('takes the address however it was typed, but not half an address', () => {
    expect(parseInput(checkEmailInput, { email: ' Karma.Treasurer@Gmail.com ' })).toEqual({
      email: 'karma.treasurer@gmail.com',
    });
    for (const [email, issue] of [
      ['karma@', 'emailIncomplete'],
      [`${'k'.repeat(250)}@gmail.com`, 'emailIncomplete'],
      ['', 'ownEmailRequired'],
      ['   ', 'ownEmailRequired'],
      [undefined, 'ownEmailRequired'],
    ]) {
      expect(() => parseInput(checkEmailInput, { email })).toThrow(
        expect.objectContaining({ details: { fields: { email: issue } } }),
      );
    }
  });
});

describe('displayNameFromEmail', () => {
  it.each([
    ['ruth.a@example.com', 'Ruth A'],
    ['sonam_wangchuk@gmail.com', 'Sonam Wangchuk'],
    ['dolma@jangchub.org', 'Dolma'],
    ['..pema..lhamo@outlook.com', 'Pema Lhamo'],
  ])('%s → %s', (email, name) => {
    expect(displayNameFromEmail(email)).toBe(name);
  });

  it('falls back to the address when there is nothing to make a name from', () => {
    expect(displayNameFromEmail('._@example.com')).toBe('._@example.com');
  });
});
