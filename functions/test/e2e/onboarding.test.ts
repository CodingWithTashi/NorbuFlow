import { randomUUID } from 'node:crypto';

import { beforeAll, describe, expect, it } from 'vitest';

import { accountsFor, call, operate, signInWithEmailLink, upload } from '../support/emulators';
import { pageCount, textOn } from '../support/pdf';
import { photo } from '../support/photos';

// A temple's first day: the operator registers it, its admin signs in, and
// adds, lists and changes members. One in-memory database (see `test:e2e`).
const lama = 'lama.karma@drolmaling.example';
const templeId = 'drolma-ling-centre';

describe('registering a temple', () => {
  it('turns away anyone without the operator’s key', async () => {
    const temple = { name: 'Nobody’s Temple', timeZone: 'America/Toronto' };

    expect((await operate('temples-create', temple, 'a-guess')).status).toBe(401);
    expect((await operate('temples-create', temple, null)).status).toBe(401);
    // A signed-in member of staff is not the operator either.
    const idToken = await signInWithEmailLink('front.desk@example.org');
    expect((await operate('temples-create', temple, idToken)).status).toBe(401);
  });

  it('says what is wrong with a request it cannot use', async () => {
    const { status, body } = await operate('temples-create', { name: ' ', timeZone: 'Toronto' });

    expect(status).toBe(400);
    expect(Object.keys(body.error.fields)).toEqual(['name', 'timeZone']);
  });

  it('registers it once, however often the request is sent', async () => {
    const temple = {
      name: 'Drolma Ling Centre',
      description: 'Kagyu tradition · Vancouver',
      timeZone: 'America/Vancouver',
    };

    const first = await operate('temples-create', temple);
    const again = await operate('temples-create', temple);

    expect(first.status, JSON.stringify(first.body)).toBe(200);
    expect(first.body.temple).toEqual({
      id: templeId,
      name: 'Drolma Ling Centre',
      description: 'Kagyu tradition · Vancouver',
      timeZone: 'America/Vancouver',
      cardTemplate: 'standard',
      membership: { kind: 'rolling', months: 12 },
      hasLogo: false,
    });
    expect(again.status).toBe(409);
    expect(again.body.error).toMatchObject({ kind: 'conflict', reason: 'templeExists' });
  });

  it('takes its logo as a file', async () => {
    const png = await photo(300, 300, 'png');

    const stored = await upload(`temples-setLogo?templeId=${templeId}`, png, 'image/png');
    const nowhere = await upload('temples-setLogo?templeId=no-such-temple', png, 'image/png');
    const notAPicture = await upload(
      `temples-setLogo?templeId=${templeId}`,
      Buffer.from('hello'),
      'text/plain',
    );

    expect(stored.status, JSON.stringify(stored.body)).toBe(200);
    expect(stored.body.temple).toMatchObject({ id: templeId, hasLogo: true });
    expect(nowhere.status).toBe(404);
    expect(notAPicture.status).toBe(400);
  });

  it('assigns it to its admin, who then has an account to sign in to', async () => {
    const { status, body } = await operate('temples-addAdmin', {
      templeId,
      email: 'Lama.Karma@DrolmaLing.example',
    });

    expect(status, JSON.stringify(body)).toBe(200);
    expect(body).toMatchObject({ temple: { id: templeId }, email: lama, role: 'admin' });
    expect(await accountsFor(lama)).toHaveLength(1);

    // Sent again, there is still one account.
    await operate('temples-addAdmin', { templeId, email: lama });
    expect(await accountsFor(lama)).toHaveLength(1);
  });
});

describe('the admin’s first day', () => {
  let idToken: string;
  let portrait: string;

  beforeAll(async () => {
    idToken = await signInWithEmailLink(lama);
    portrait = (await photo(1200, 1600)).toString('base64');
  });

  it('signs them in, and shows them the one temple that is theirs', async () => {
    const session = await call('auth-startSession', null, idToken);
    const { status, body } = await call('temples-list', null, idToken);

    expect(session.status, JSON.stringify(session.body)).toBe(200);
    expect(status, JSON.stringify(body)).toBe(200);
    expect(body.result.temples).toEqual([
      {
        id: templeId,
        name: 'Drolma Ling Centre',
        description: 'Kagyu tradition · Vancouver',
        role: 'admin',
        logo: expect.any(String),
      },
    ]);
    // A PNG, as the app shows it.
    const logo = Buffer.from(body.result.temples[0].logo, 'base64');
    expect([...logo.subarray(1, 4)]).toEqual([0x50, 0x4e, 0x47]);
  });

  it('shows no temple to someone who was never added', async () => {
    const stranger = await signInWithEmailLink('visitor@example.org');

    const { status, body } = await call('temples-list', null, stranger);

    expect(status).toBe(403);
    expect(body.error.details.reason).toBe('notOnTeam');
  });

  it('previews, adds, lists, changes and replaces members', async () => {
    // A preview draws the card and takes no number.
    const preview = await call(
      'members-preview',
      { name: 'Yeshi Lhamo', photo: portrait },
      idToken,
    );
    expect(preview.status, JSON.stringify(preview.body)).toBe(200);
    expect(preview.body.result).toMatchObject({ number: '1', label: '1' });
    const previewed = Buffer.from(preview.body.result.card.pdf, 'base64');
    expect((await textOn(previewed, 1)).map((run) => run.text)).toEqual([
      'Drolma Ling Centre',
      'Yeshi Lhamo',
      expect.stringMatching(/^Valid until \d{1,2} \w+ \d{4}$/),
      'Membership number',
      '1',
    ]);

    // Neither phone nor email is needed.
    const yeshi = { id: randomUUID(), name: 'Yeshi Lhamo', photo: portrait };
    const added = await call('members-create', yeshi, idToken);
    expect(added.status, JSON.stringify(added.body)).toBe(200);
    expect(added.body.result.member).toMatchObject({
      id: yeshi.id,
      number: '1',
      phone: null,
      email: null,
    });
    expect(await pageCount(Buffer.from(added.body.result.card.pdf, 'base64'))).toBe(2);

    // A number typed by hand, in the preview and then for real.
    const chosen = await call(
      'members-preview',
      { name: 'Ngawang Choedon', photo: portrait, number: '0044' },
      idToken,
    );
    expect(chosen.body.result).toMatchObject({ number: '44', label: '44' });
    const ngawang = {
      id: randomUUID(),
      name: 'Ngawang Choedon',
      phone: '+1 604 555 0144',
      email: 'Ngawang@Example.org',
      photo: portrait,
      number: '44',
    };
    const second = await call('members-create', ngawang, idToken);
    expect(second.body.result.member).toMatchObject({
      number: '44',
      phone: '+1 604 555 0144',
      email: 'ngawang@example.org',
    });

    // The list is the temple's own, newest first.
    const listed = await call('members-list', null, idToken);
    expect(listed.status, JSON.stringify(listed.body)).toBe(200);
    expect(listed.body.result.members).toEqual([
      second.body.result.member,
      added.body.result.member,
    ]);

    // A number someone holds adds nobody, and says who has it.
    const robert = { id: randomUUID(), name: 'Robert Chen', photo: portrait, number: '44' };
    const refused = await call('members-create', robert, idToken);
    expect(refused.status).toBe(200);
    expect(refused.body.result).toEqual({ taken: { name: 'Ngawang Choedon', number: '44' } });

    // Replacing gives the record, and its number, to the new person.
    const replaced = await call('members-create', { ...robert, replace: true }, idToken);
    expect(replaced.body.result.member).toMatchObject({
      id: ngawang.id,
      number: '44',
      name: 'Robert Chen',
      phone: null,
    });

    // A change to what the card shows prints a new card.
    const change = {
      id: randomUUID(),
      memberId: yeshi.id,
      name: 'Yeshi L. Dolkar',
      email: 'yeshi@example.org',
      number: '7',
    };
    const changed = await call('members-update', change, idToken);
    expect(changed.status, JSON.stringify(changed.body)).toBe(200);
    expect(changed.body.result.member).toMatchObject({
      id: yeshi.id,
      number: '7',
      name: 'Yeshi L. Dolkar',
      email: 'yeshi@example.org',
    });
    // One already taken changes nothing.
    const clash = await call(
      'members-update',
      { ...change, id: randomUUID(), number: '44' },
      idToken,
    );
    expect(clash.body.result).toEqual({ taken: { name: 'Robert Chen', number: '44' } });

    // The card on file is the last one issued.
    const card = await call('members-card', { memberId: yeshi.id }, idToken);
    expect(card.status, JSON.stringify(card.body)).toBe(200);
    expect(card.body.result).toEqual(changed.body.result);
    const printed = await textOn(Buffer.from(card.body.result.card.pdf, 'base64'), 1);
    expect(printed.map((run) => run.text)).toEqual(
      expect.arrayContaining(['Yeshi L. Dolkar', '7']),
    );

    const gone = await call('members-card', { memberId: randomUUID() }, idToken);
    expect(gone.status).toBe(404);
  });

  it('names each field at fault when a member cannot be used', async () => {
    const { status, body } = await call(
      'members-create',
      { id: randomUUID(), name: 'Tenzin Dolma', phone: '555', number: 'DL-7', photo: portrait },
      idToken,
    );

    expect(status).toBe(400);
    expect(body.error.details.fields).toEqual({
      phone: 'phoneTooShort',
      number: 'memberNumberInvalid',
    });
  });
});
