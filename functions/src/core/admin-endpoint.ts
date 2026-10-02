import { createHash, timingSafeEqual } from 'node:crypto';

import * as logger from 'firebase-functions/logger';
import {
  type HttpsFunction,
  type HttpsOptions,
  onRequest,
  type Request,
} from 'firebase-functions/v2/https';
import type { z } from 'zod';

import { setting } from './environment';
import { AppError, type ErrorKind } from './errors';
import { parseInput } from './validation';

interface AdminEndpointSpec<S extends z.ZodType, O> {
  /** Per-function overrides of the global options (memory, …). */
  options?: HttpsOptions;
  input: S;
  /** What `input` checks. Leave out for the request's JSON body. */
  read?: (request: AdminRequest) => unknown;
  handler: (input: z.output<S>) => Promise<O>;
}

/** The part of a request an admin endpoint looks at. */
export type AdminRequest = Pick<Request, 'method' | 'headers' | 'body' | 'query' | 'rawBody'>;

/**
 * Declares a function only NorbuFlow's operator may call, by sending
 * `Authorization: Bearer <ADMIN_KEY>`. The app has no such key.
 */
export function defineAdminEndpoint<O, S extends z.ZodType>(
  spec: AdminEndpointSpec<S, O>,
): HttpsFunction {
  return onRequest(spec.options ?? {}, async (request, response) => {
    const { status, body } = await answerAdmin(spec, request);
    response.status(status).json(body);
  });
}

const statuses: Record<ErrorKind, number> = {
  unauthenticated: 401,
  permissionDenied: 403,
  invalid: 400,
  notFound: 404,
  conflict: 409,
};

/** Checks the key and the input, runs the handler, and words any failure. */
export async function answerAdmin<O, S extends z.ZodType>(
  spec: AdminEndpointSpec<S, O>,
  request: AdminRequest,
): Promise<{ status: number; body: unknown }> {
  try {
    if (request.method !== 'POST') return refusal(405, 'methodNotAllowed', 'Use POST.');
    if (!hasAdminKey(request.headers.authorization)) throw AppError.unauthenticated('Wrong key.');
    const read = spec.read ?? ((from: AdminRequest) => from.body as unknown);
    const input = parseInput(spec.input, read(request)) as z.output<S>;
    return { status: 200, body: await spec.handler(input) };
  } catch (error) {
    if (error instanceof AppError) {
      logger.info(`Refused: ${error.message}`, { kind: error.kind, ...error.details });
      return refusal(statuses[error.kind], error.kind, error.message, error.details);
    }
    logger.error('Failed', error);
    return refusal(500, 'internal', 'Something went wrong. The logs say what.');
  }
}

function refusal(status: number, kind: string, message: string, details: object = {}) {
  return { status, body: { error: { kind, message, ...details } } };
}

// Digests are compared, so the time taken says nothing about the key's length.
function hasAdminKey(header: string | undefined): boolean {
  const digest = (value: string) => createHash('sha256').update(value).digest();
  return timingSafeEqual(digest(header ?? ''), digest(`Bearer ${setting('ADMIN_KEY')}`));
}
