import type { z } from 'zod';

import { AppError } from './errors';

/** Typed text has no control characters, one of which Postgres cannot store. */
export const noControlChars = /^\P{Cc}*$/u;

// What a problem with the request as a whole is filed under.
const wholeRequest = 'request';

/**
 * Checks request data against `schema`, whose error messages are the app's
 * `ValidationIssue` names (`z.email('emailIncomplete')`).
 */
export function parseInput<T>(schema: z.ZodType<T>, data: unknown): T {
  const result = schema.safeParse(data);
  if (result.success) return result.data;

  const fields: Record<string, string> = {};
  for (const issue of result.error.issues) {
    // The first problem with a field is the one worth showing.
    fields[issue.path.join('.') || wholeRequest] ??= issue.message;
  }
  throw AppError.invalid(fields);
}
