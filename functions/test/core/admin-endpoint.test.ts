import * as logger from 'firebase-functions/logger';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { z } from 'zod';

import { type AdminRequest, answerAdmin } from '../../src/core/admin-endpoint';
import { AppError } from '../../src/core/errors';

vi.mock('firebase-functions/logger');

const greet = {
  input: z.object({ name: z.string('Send a name.') }),
  handler: vi.fn(async (input: { name: string }) => ({ hello: input.name })),
};

const request = (changes: Partial<AdminRequest> = {}) =>
  ({
    method: 'POST',
    headers: { authorization: 'Bearer the-operators-key' },
    body: { name: 'Drolma Ling' },
    query: {},
    ...changes,
  }) as AdminRequest;

describe('an admin endpoint', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.stubEnv('ADMIN_KEY', 'the-operators-key');
  });
  afterEach(() => vi.unstubAllEnvs());

  it('answers the operator with what the handler returns', async () => {
    await expect(answerAdmin(greet, request())).resolves.toEqual({
      status: 200,
      body: { hello: 'Drolma Ling' },
    });
  });

  describe('turns away', () => {
    it.each([
      ['no key', undefined],
      ['another key', 'Bearer someone-elses-key'],
      ['the key without "Bearer"', 'the-operators-key'],
      ['a key that only starts the same', 'Bearer the-operators-key-and-more'],
    ])('%s', async (_, authorization) => {
      const answer = await answerAdmin(greet, request({ headers: { authorization } }));

      expect(answer).toMatchObject({ status: 401, body: { error: { kind: 'unauthenticated' } } });
      expect(greet.handler).not.toHaveBeenCalled();
    });

    it('everyone, when no key has been set', async () => {
      vi.stubEnv('ADMIN_KEY', '');

      const answer = await answerAdmin(greet, request({ headers: { authorization: 'Bearer ' } }));

      expect(answer.status).toBe(500);
      expect(greet.handler).not.toHaveBeenCalled();
    });

    it('anything but a POST', async () => {
      const answer = await answerAdmin(greet, request({ method: 'GET' }));

      expect(answer).toMatchObject({ status: 405, body: { error: { kind: 'methodNotAllowed' } } });
      expect(greet.handler).not.toHaveBeenCalled();
    });
  });

  it('checks the key before reading the input', async () => {
    const answer = await answerAdmin(greet, request({ headers: {}, body: {} }));

    expect(answer.status).toBe(401);
  });

  it('names each field at fault, in words', async () => {
    const answer = await answerAdmin(greet, request({ body: {} }));

    expect(answer).toEqual({
      status: 400,
      body: {
        error: {
          kind: 'invalid',
          message: 'The request was not valid.',
          fields: { name: 'Send a name.' },
        },
      },
    });
  });

  it('reads the input from wherever it is told to', async () => {
    const fromAddress = { ...greet, read: (from: AdminRequest) => ({ name: from.query.name }) };

    const answer = await answerAdmin(fromAddress, request({ body: {}, query: { name: 'Query' } }));

    expect(answer.body).toEqual({ hello: 'Query' });
  });

  describe('errors', () => {
    const failing = (error: unknown) =>
      answerAdmin({ ...greet, handler: () => Promise.reject(error) }, request());

    it('gives each kind of AppError its own status, with its message and reason', async () => {
      await expect(failing(AppError.notFound('No such temple.'))).resolves.toEqual({
        status: 404,
        body: { error: { kind: 'notFound', message: 'No such temple.' } },
      });
      await expect(failing(AppError.conflict('Already there.', 'templeExists'))).resolves.toEqual({
        status: 409,
        body: { error: { kind: 'conflict', message: 'Already there.', reason: 'templeExists' } },
      });
      await expect(failing(AppError.permissionDenied('No.'))).resolves.toMatchObject({
        status: 403,
      });
    });

    it('logs anything unexpected and sends none of its detail', async () => {
      const error = new Error('connection string postgres://secret');

      const answer = await failing(error);

      expect(answer.status).toBe(500);
      expect(JSON.stringify(answer.body)).not.toContain('secret');
      expect(logger.error).toHaveBeenCalledWith('Failed', error);
    });
  });
});
