/** What went wrong, in the backend's own terms: not yet a response of any kind. */
export type ErrorKind =
  'unauthenticated' | 'permissionDenied' | 'invalid' | 'notFound' | 'conflict';

/**
 * What is told beyond the kind. To the app, `reason` and the values of
 * `fields` are names of its Dart enums; to the operator, plain words.
 */
export interface ErrorDetails {
  reason?: string;
  /** Rejected input: field name → `ValidationIssue` name. */
  fields?: Record<string, string>;
}

/**
 * A failure the app is meant to see; anything else that escapes a function is
 * reported as `internal`. `message` is for developers: the app words failures itself.
 */
export class AppError extends Error {
  private constructor(
    readonly kind: ErrorKind,
    message: string,
    readonly details: ErrorDetails = {},
  ) {
    super(message);
    this.name = 'AppError';
  }

  static unauthenticated(message = 'Sign in to continue.'): AppError {
    return new AppError('unauthenticated', message);
  }

  static permissionDenied(message: string, reason?: string): AppError {
    return new AppError('permissionDenied', message, { reason });
  }

  static invalid(fields: Record<string, string>): AppError {
    return new AppError('invalid', 'The request was not valid.', { fields });
  }

  static notFound(message: string): AppError {
    return new AppError('notFound', message);
  }

  static conflict(message: string, reason?: string): AppError {
    return new AppError('conflict', message, { reason });
  }
}
