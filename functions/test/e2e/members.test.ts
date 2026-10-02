import { randomUUID } from 'node:crypto';

import { describe, expect, it } from 'vitest';

import { call, signInWithEmailLink } from '../support/emulators';
import { pageCount, textOn } from '../support/pdf';
import { photo } from '../support/photos';

// The feature as the app uses it, against the emulators. As a demo project
// they run on an in-memory database and file store.
const frontDesk = 'front.desk@example.org';

describe('members-create', () => {
  it('returns the new member and their print-ready card', async () => {
    const idToken = await signInWithEmailLink(frontDesk);
    const portrait = (await photo(1200, 1600)).toString('base64');
    const tenzin = {
      id: randomUUID(),
      name: 'Tenzin Dolma',
      phone: '416 555 0142',
      email: 'Tenzin.Dolma@example.org',
      photo: portrait,
    };

    const first = await call('members-create', tenzin, idToken);
    const second = await call(
      'members-create',
      { id: randomUUID(), name: 'Karma Dhondup', phone: '(647) 555-0188', photo: portrait },
      idToken,
    );

    expect(first.status, JSON.stringify(first.body)).toBe(200);
    const { member, card } = first.body.result;
    expect(member).toEqual({
      id: tenzin.id,
      number: '194915308',
      name: 'Tenzin Dolma',
      email: 'tenzin.dolma@example.org',
      phone: '416 555 0142',
      joinedOn: expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
      renewedOn: member.joinedOn,
      expiresOn: expect.stringMatching(/^\d{4}-07-31$/),
      // The card is the request's own, and its photo is filed beside it.
      cardId: tenzin.id,
      photoKey: expect.stringMatching(
        new RegExp(`/members/${tenzin.id}/cards/${tenzin.id}\\.jpg$`),
      ),
      // The emulators keep files in memory, which nothing can link to.
      photoUrl: null,
    });
    expect(second.body.result.member).toMatchObject({ number: '194915309', email: null });

    const pdf = Buffer.from(card.pdf, 'base64');
    expect(await pageCount(pdf)).toBe(2);
    const printed = (await textOn(pdf, 1)).map((run) => run.text);
    expect(printed).toContain('Tenzin Dolma');
    expect(printed).toContain('194915308');

    // The app asking again, as it does when the answer never arrived.
    const again = await call('members-create', tenzin, idToken);
    expect(again.body.result).toEqual(first.body.result);
  });

  it('names each field at fault when the request cannot be used', async () => {
    const idToken = await signInWithEmailLink(frontDesk);

    const { status, body } = await call(
      'members-create',
      { id: randomUUID(), name: ' ', phone: '555 0142', email: 'tenzin@', photo: 'not base64!' },
      idToken,
    );

    expect(status).toBe(400);
    expect(body.error.details.fields).toEqual({
      name: 'memberNameRequired',
      phone: 'phoneTooShort',
      email: 'emailIncomplete',
      photo: 'photoUnreadable',
    });
  });

  it('turns away someone who is not on the temple’s team', async () => {
    const idToken = await signInWithEmailLink('visitor@example.org');
    const portrait = (await photo(600, 800)).toString('base64');

    const { status, body } = await call(
      'members-create',
      { id: randomUUID(), name: 'Tenzin Dolma', phone: '416 555 0142', photo: portrait },
      idToken,
    );

    expect(status).toBe(403);
    expect(body.error.details.reason).toBe('notOnTeam');
  });
});
