import { randomUUID } from 'node:crypto';

import { beforeAll, describe, expect, it } from 'vitest';

import { call, operate, signInWithEmailLink } from '../support/emulators';
import { pageCount, textOn } from '../support/pdf';

// The feature as the app uses it, on the emulators and their stand-ins. The
// temple with a letterhead gets an admin of its own: other tests sign in too.
const admin = 'geshe.office@example.org';
const temple = 'drepung-loseling-canada';

const body = [
  { runs: [{ text: 'This letter is to confirm that ' }, { text: 'Pema Lhamo', bold: true }] },
  { runs: [] },
  { bullet: true, runs: [{ text: 'has volunteered since 2024.' }] },
];
const nextYear = `${new Date().getFullYear() + 1}-07-16`;
const printed = async (pdf: string) =>
  (await textOn(Buffer.from(pdf, 'base64'), 1)).map((run) => run.text);

describe('letters', () => {
  let idToken: string;

  beforeAll(async () => {
    const added = await operate('temples-addAdmin', { templeId: temple, email: admin });
    expect(added.status, JSON.stringify(added.body)).toBe(200);
    idToken = await signInWithEmailLink(admin);
  });

  it('previews, issues, lists and reopens a support letter', async () => {
    const letter = { name: ' Pema Lhamo ', validUntil: nextYear, body };

    // A preview draws the letter and takes no number.
    const preview = await call('letters-preview', letter, idToken);
    expect(preview.status, JSON.stringify(preview.body)).toBe(200);
    expect(preview.body.result.number).toBe('195960');
    // Three of the 25 lines are used: it could start up to 22 lower.
    expect(preview.body.result.spare).toBe(22);
    expect(await pageCount(Buffer.from(preview.body.result.file.pdf, 'base64'))).toBe(1);
    const text = await printed(preview.body.result.file.pdf);
    expect(text).toContain('No. 195960');
    expect(text).toContain(`Valid Until Jul 16, ${nextYear.slice(0, 4)}`);
    expect(text).toContain('To Whom It May Concern');

    const request = { id: randomUUID(), ...letter };
    const issued = await call('letters-create', request, idToken);
    expect(issued.status, JSON.stringify(issued.body)).toBe(200);
    expect(issued.body.result.letter).toEqual({
      id: request.id,
      number: '195960',
      name: 'Pema Lhamo',
      memberId: null,
      validUntil: nextYear,
      issuedOn: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
    });
    expect(await printed(issued.body.result.file.pdf)).toContain('No. 195960');

    // The app asking again, as it does when the answer never arrived.
    const again = await call('letters-create', request, idToken);
    expect(again.body.result).toEqual(issued.body.result);

    // A number typed by hand, and the letter moved four lines down the page.
    const lower = [...Array(4).fill({ runs: [] }), ...body];
    const chosen = await call(
      'letters-preview',
      { ...letter, body: lower, number: '00195970' },
      idToken,
    );
    expect(chosen.body.result).toMatchObject({ number: '195970', spare: 18 });
    const typed = { id: randomUUID(), ...letter, name: 'Karma Dhondup', number: '195970' };
    expect((await call('letters-create', typed, idToken)).body.result.letter).toMatchObject({
      number: '195970',
    });

    // A number another letter carries is an answer, not an error.
    const taken = await call(
      'letters-create',
      { id: randomUUID(), ...letter, number: '195960' },
      idToken,
    );
    expect(taken.status).toBe(200);
    expect(taken.body.result).toEqual({ taken: { name: 'Pema Lhamo', number: '195960' } });

    // Newest first, and each comes back with what it says.
    const listed = await call('letters-list', null, idToken);
    expect(listed.body.result.letters.map((each: { number: string }) => each.number)).toEqual([
      '195970',
      '195960',
    ]);
    const onFile = await call('letters-get', { letterId: request.id }, idToken);
    expect(onFile.body.result.letter).toEqual(issued.body.result.letter);
    expect(onFile.body.result.body).toEqual(body);
    expect(onFile.body.result.file.pdf).toBe(issued.body.result.file.pdf);
  });

  it('answers a body too long for the page with how far over it is', async () => {
    const long = Array(27).fill({ runs: [{ text: 'One line of the letter.' }] });

    const preview = await call(
      'letters-preview',
      { name: 'Pema Lhamo', validUntil: nextYear, body: long },
      idToken,
    );

    expect(preview.status, JSON.stringify(preview.body)).toBe(200);
    expect(preview.body.result).toEqual({ tooLong: { lines: 2 } });
  });

  it('says which field is wrong in words the app knows', async () => {
    const { status, body: answer } = await call(
      'letters-create',
      { id: randomUUID(), name: ' ', validUntil: '2020-01-01', body: [], number: 'A1' },
      idToken,
    );
    const past = await call(
      'letters-preview',
      { name: 'Pema Lhamo', validUntil: '2020-01-01', body },
      idToken,
    );

    expect(status).toBe(400);
    expect(answer.error.details.fields).toEqual({
      name: 'letterNameRequired',
      body: 'letterBodyRequired',
      number: 'letterNumberInvalid',
    });
    expect(past.body.error.details.fields).toEqual({ validUntil: 'letterDatePast' });
  });

  it('turns away anyone who is not on the temple’s team', async () => {
    const stranger = await signInWithEmailLink('visitor@example.org');

    const { status, body: answer } = await call('letters-list', null, stranger);

    expect(status).toBe(403);
    expect(answer.error.details.reason).toBe('notOnTeam');
    expect((await call('letters-list', null)).status).toBe(401);
  });
});
