import { expect } from 'vitest';

// Ports and region match firebase.json and core/options.
const project = 'demo-norbu-flow';
const authEmulator = 'http://127.0.0.1:9099';
const identity = `${authEmulator}/identitytoolkit.googleapis.com/v1`;
const functions = `http://127.0.0.1:5001/${project}/us-central1`;

async function post(url: string, body: unknown, idToken?: string) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

/** Calls a deployed function the way the app's SDK does. */
export function call(name: string, data: unknown, idToken?: string) {
  return post(`${functions}/${name}`, { data }, idToken);
}

/** ADMIN_KEY in .env.demo-norbu-flow. */
export const operatorKey = 'e2e-operator-key';

/** Calls an operator's endpoint the way curl does: JSON in, JSON out. `null` sends no key. */
export function operate(name: string, body: unknown, key: string | null = operatorKey) {
  return post(`${functions}/${name}`, body, key ?? undefined);
}

/** Sends a file as the body of a request to an operator's endpoint. */
export async function upload(name: string, bytes: Uint8Array, contentType: string) {
  const response = await fetch(`${functions}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': contentType, Authorization: `Bearer ${operatorKey}` },
    // Bytes of its own, not a view of shared memory, which fetch does not take.
    body: new Uint8Array(bytes),
  });
  return { status: response.status, body: await response.json() };
}

/** The accounts Firebase Authentication has for `email`. */
export async function accountsFor(email: string): Promise<{ email: string }[]> {
  const { body } = await post(
    `${identity}/projects/${project}/accounts:lookup`,
    { email: [email] },
    // How the emulator is told a request comes from the Admin SDK.
    'owner',
  );
  return body.users ?? [];
}

/** What the app does: ask for a link, then exchange the one that arrives. */
export async function signInWithEmailLink(email: string): Promise<string> {
  await post(`${identity}/accounts:sendOobCode?key=fake`, {
    requestType: 'EMAIL_SIGNIN',
    email,
    continueUrl: `https://${project}.firebaseapp.com`,
  });
  const sent = await fetch(`${authEmulator}/emulator/v1/projects/${project}/oobCodes`);
  const { oobCodes } = (await sent.json()) as { oobCodes: { email: string; oobCode: string }[] };
  // Firebase lower-cases the address it sends to.
  const oobCode = oobCodes.findLast((code) => code.email === email.toLowerCase())?.oobCode;

  const { body } = await post(`${identity}/accounts:signInWithEmailLink?key=fake`, {
    email,
    oobCode,
  });
  expect(body.idToken, JSON.stringify(body)).toEqual(expect.any(String));
  return body.idToken;
}

/** An account made with a password, whose email was therefore never proven. */
export async function signUpWithPassword(email: string): Promise<string> {
  const { body } = await post(`${identity}/accounts:signUp?key=fake`, {
    email,
    password: 'not-a-link',
    returnSecureToken: true,
  });
  return body.idToken;
}
