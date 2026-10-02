import { describe, expect, it } from 'vitest';

import { call, signInWithEmailLink, signUpWithPassword } from '../support/emulators';

// The real sign-in flow against the emulators. Only `front.desk@example.org`
// is on the temple's team (LOCAL_STAFF_EMAIL in .env.demo-norbu-flow).
const startSession = (idToken?: string) => call('auth-startSession', null, idToken);

describe('auth-startSession', () => {
  it('opens a session for someone a temple has invited', async () => {
    const idToken = await signInWithEmailLink('Front.Desk@example.org');

    const first = await startSession(idToken);
    const again = await startSession(idToken);

    expect(first.status, JSON.stringify(first.body)).toBe(200);
    expect(first.body.result.user).toEqual({
      id: expect.any(String),
      email: 'front.desk@example.org',
      displayName: 'Front Desk',
    });
    expect(again.body).toEqual(first.body);
  });

  it('turns away a proven email that no temple has invited', async () => {
    const idToken = await signInWithEmailLink('visitor@example.org');

    const { status, body } = await startSession(idToken);

    expect(status).toBe(403);
    expect(body.error.details.reason).toBe('notOnTeam');
  });

  it('turns away a call with no session', async () => {
    const { status, body } = await startSession();

    expect(status).toBe(401);
    expect(body.error.status).toBe('UNAUTHENTICATED');
  });

  it('turns away an account made with a password, whose email is unproven', async () => {
    const idToken = await signUpWithPassword('front.desk.impostor@example.org');

    const { status, body } = await startSession(idToken);

    expect(status).toBe(401);
    expect(body.error.status).toBe('UNAUTHENTICATED');
  });
});

describe('auth-checkEmail', () => {
  const checkEmail = (email: unknown) => call('auth-checkEmail', { email });

  it('tells the sign-in screen, before anyone is signed in, whether an address was added', async () => {
    const added = await checkEmail(' Front.Desk@Example.org ');
    const stranger = await checkEmail('visitor@example.org');

    expect(added.status, JSON.stringify(added.body)).toBe(200);
    expect(added.body.result).toEqual({ invited: true });
    expect(stranger.body.result).toEqual({ invited: false });
  });

  it('refuses half an address, naming the field', async () => {
    const { status, body } = await checkEmail('visitor@');

    expect(status).toBe(400);
    expect(body.error.details.fields).toEqual({ email: 'emailIncomplete' });
  });
});
