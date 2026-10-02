import type { CallableRequest } from 'firebase-functions/v2/https';

import { AppError } from './errors';

/** The signed-in person making a call. */
export interface Caller {
  readonly uid: string;
  /** Lower-cased, and proven to be theirs. */
  readonly email: string;
}

/**
 * Accepts only a session whose email is proven (`email_verified`), which is
 * what signing in by email link does. A password sign-up proves nothing.
 */
export function requireCaller(auth: CallableRequest['auth']): Caller {
  const email = auth?.token.email;
  if (!auth || !email || auth.token.email_verified !== true) {
    throw AppError.unauthenticated();
  }
  return { uid: auth.uid, email: email.toLowerCase() };
}
