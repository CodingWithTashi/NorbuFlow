import * as logger from 'firebase-functions/logger';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { z } from 'zod';

import { defineCallable, definePublicCallable } from '../../src/core/callable';
import { AppError } from '../../src/core/errors';
import { callableRequest, session, signedIn } from '../support/requests';

vi.mock('firebase-functions/logger');

const whoAmI = defineCallable({
  handler: async (caller) => caller,
});

const invite = defineCallable({
  input: z.object({
    email: z.email('emailIncomplete'),
    role: z.enum(['admin', 'member'], 'roleUnknown'),
  }),
  handler: async (_, input) => input,
});

describe('defineCallable', () => {
  beforeEach(() => vi.clearAllMocks());

  describe('caller', () => {
    it('turns away a call with no session', async () => {
      await expect(whoAmI.run(callableRequest())).rejects.toMatchObject({
        code: 'unauthenticated',
      });
    });

    it('turns away a session whose email was never proven', async () => {
      const passwordSignUp = session('uid-2', { email: 'a@b.co', email_verified: false });
      const anonymous = session('uid-3', {});

      for (const auth of [passwordSignUp, anonymous]) {
        await expect(whoAmI.run(callableRequest(auth))).rejects.toMatchObject({
          code: 'unauthenticated',
        });
      }
    });

    it('hands the handler who is calling, with the email lower-cased', async () => {
      const request = callableRequest(signedIn('Dolma@Jangchub.org', 'uid-7'));

      await expect(whoAmI.run(request)).resolves.toEqual({
        uid: 'uid-7',
        email: 'dolma@jangchub.org',
      });
    });
  });

  describe('input', () => {
    const dolma = signedIn('dolma@jangchub.org');

    it('hands the handler input that matches the schema', async () => {
      const input = { email: 'ruth.a@example.com', role: 'member' };

      await expect(invite.run(callableRequest(dolma, input))).resolves.toEqual(input);
    });

    it('rejects bad input, naming each field and its issue', async () => {
      const request = callableRequest(dolma, { email: 'ruth@', role: 'abbot' });

      await expect(invite.run(request)).rejects.toMatchObject({
        code: 'invalid-argument',
        details: { fields: { email: 'emailIncomplete', role: 'roleUnknown' } },
      });
    });

    it('checks who is calling before reading the input', async () => {
      await expect(invite.run(callableRequest(undefined, {}))).rejects.toMatchObject({
        code: 'unauthenticated',
      });
    });
  });

  describe('errors', () => {
    const failing = (error: unknown) =>
      defineCallable({
        handler: async () => {
          throw error;
        },
      }).run(callableRequest(signedIn('dolma@jangchub.org')));

    it('sends an AppError to the app with its code and reason, and notes it', async () => {
      const error = AppError.permissionDenied('Not on the team.', 'notOnTeam');

      await expect(failing(error)).rejects.toMatchObject({
        code: 'permission-denied',
        details: { reason: 'notOnTeam' },
      });
      expect(logger.error).not.toHaveBeenCalled();
      expect(logger.info).toHaveBeenCalledWith('Refused: Not on the team.', {
        kind: 'permissionDenied',
        reason: 'notOnTeam',
      });
    });

    it('gives each kind of AppError its own status', async () => {
      await expect(failing(AppError.unauthenticated())).rejects.toMatchObject({
        code: 'unauthenticated',
      });
      await expect(failing(AppError.permissionDenied('No.'))).rejects.toMatchObject({
        code: 'permission-denied',
      });
      await expect(failing(AppError.invalid({ name: 'x' }))).rejects.toMatchObject({
        code: 'invalid-argument',
        details: { fields: { name: 'x' } },
      });
      await expect(failing(AppError.notFound('Gone.'))).rejects.toMatchObject({
        code: 'not-found',
      });
      await expect(failing(AppError.conflict('Taken.', 'numberTaken'))).rejects.toMatchObject({
        code: 'already-exists',
        details: { reason: 'numberTaken' },
      });
    });

    it('logs anything unexpected and sends none of its detail', async () => {
      const error = new Error('connection string postgres://secret');

      await expect(failing(error)).rejects.toMatchObject({
        code: 'internal',
        message: 'Something went wrong.',
      });
      expect(logger.error).toHaveBeenCalledWith('Failed', error);
    });
  });
});

describe('definePublicCallable', () => {
  const echo = definePublicCallable({
    input: z.object({ email: z.email('emailIncomplete') }),
    handler: async (input) => ({ asked: input.email }),
  });

  it('answers a call with no session at all', async () => {
    await expect(echo.run(callableRequest(undefined, { email: 'a@b.co' }))).resolves.toEqual({
      asked: 'a@b.co',
    });
  });

  it('still checks its input and reports errors the same way', async () => {
    await expect(echo.run(callableRequest(undefined, { email: 'a@' }))).rejects.toMatchObject({
      code: 'invalid-argument',
      details: { fields: { email: 'emailIncomplete' } },
    });

    const failing = definePublicCallable({
      input: z.object({}),
      handler: async () => {
        throw new Error('connection string postgres://secret');
      },
    });
    await expect(failing.run(callableRequest(undefined, {}))).rejects.toMatchObject({
      code: 'internal',
      message: 'Something went wrong.',
    });
  });
});
