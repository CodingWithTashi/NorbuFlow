import type { CallableRequest } from 'firebase-functions/v2/https';

type AuthData = NonNullable<CallableRequest['auth']>;

/** The session of someone who signed in with an email link. */
export function signedIn(email: string, uid = 'uid-1'): AuthData {
  return session(uid, { email, email_verified: true });
}

export function session(uid: string, claims: Record<string, unknown>): AuthData {
  return { uid, token: { uid, ...claims }, rawToken: '' } as AuthData;
}

export function callableRequest(auth?: AuthData, data: unknown = null): CallableRequest<unknown> {
  return { auth, data, acceptsStreaming: false } as CallableRequest<unknown>;
}
