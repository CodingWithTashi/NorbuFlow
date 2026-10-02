import type { z } from 'zod';

import { AppError } from './errors';

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
    fields[issue.path.join('.')] ??= issue.message;
  }
  throw AppError.invalid(fields);
}
