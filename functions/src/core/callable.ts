import * as logger from 'firebase-functions/logger';
import {
  type CallableFunction,
  type CallableOptions,
  type FunctionsErrorCode,
  HttpsError,
  onCall,
} from 'firebase-functions/v2/https';
import type { z } from 'zod';

import { type Caller, requireCaller } from './caller';
import { AppError, type ErrorKind } from './errors';
import { parseInput } from './validation';

interface CallableSpec<S extends z.ZodType, O> {
  /** Per-function overrides of the global options (memory, secrets, …). */
  options?: CallableOptions;
  /** The shape of the request data. Leave out for a call that takes none. */
  input?: S;
  handler: (caller: Caller, input: z.output<S>) => Promise<O>;
}

/**
 * Declares a function the app can call. Every callable is built here, so each
 * checks the caller, validates its input and reports errors the same way.
 */
export function defineCallable<O, S extends z.ZodType = z.ZodVoid>(
  spec: CallableSpec<S, O>,
): CallableFunction<unknown, Promise<O>> {
  return onCall<unknown, Promise<O>>(spec.options ?? {}, async (request) => {
    try {
      const caller = requireCaller(request.auth);
      // With no schema, `S` is `ZodVoid` and the handler expects `undefined`.
      const input = (spec.input ? parseInput(spec.input, request.data) : undefined) as z.output<S>;
      return await spec.handler(caller, input);
    } catch (error) {
      throw toHttpsError(error);
    }
  });
}

interface PublicCallableSpec<S extends z.ZodType, O> {
  options?: CallableOptions;
  input: S;
  handler: (input: z.output<S>) => Promise<O>;
}

/**
 * Declares a function the app calls before anyone is signed in. It has no
 * caller to trust, so it must give away nothing a stranger should not learn.
 */
export function definePublicCallable<O, S extends z.ZodType>(
  spec: PublicCallableSpec<S, O>,
): CallableFunction<unknown, Promise<O>> {
  return onCall<unknown, Promise<O>>(spec.options ?? {}, async (request) => {
    try {
      return await spec.handler(parseInput(spec.input, request.data) as z.output<S>);
    } catch (error) {
      throw toHttpsError(error);
    }
  });
}

const codes: Record<ErrorKind, FunctionsErrorCode> = {
  unauthenticated: 'unauthenticated',
  permissionDenied: 'permission-denied',
  invalid: 'invalid-argument',
  notFound: 'not-found',
  conflict: 'already-exists',
};

/**
 * Where an error becomes a callable's response. Unexpected errors are logged
 * in full and sent without their detail, so nothing internal leaks.
 */
function toHttpsError(error: unknown): HttpsError {
  if (error instanceof AppError) {
    logger.info(`Refused: ${error.message}`, { kind: error.kind, ...error.details });
    return new HttpsError(codes[error.kind], error.message, error.details);
  }
  logger.error('Failed', error);
  return new HttpsError('internal', 'Something went wrong.');
}
