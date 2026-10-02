import { randomUUID } from 'node:crypto';

import { beforeEach, describe, expect, it } from 'vitest';

import type { Database } from '../../../src/core/database';
import { type FileStore, InMemoryFileStore } from '../../../src/core/file-store';
import { parseInput } from '../../../src/core/validation';
import { cardRenderer } from '../../../src/features/cards';
import { newMemberInput } from '../../../src/features/members/members.input';
import {
  membershipEnd,
  MemberService,
  type NewMemberRequest,
} from '../../../src/features/members/members.service';
import { PostgresMemberRepository } from '../../../src/features/members/postgres-member.repository';
import { PostgresTempleRepository } from '../../../src/features/temples/postgres-temple.repository';
import { TempleAccess } from '../../../src/features/temples/temple-access';
import { addToTeam, freshDatabase, loseling } from '../../support/database';
import { pageCount, textOn } from '../../support/pdf';
import { photo } from '../../support/photos';

const dolma = { uid: 'uid-dolma', email: 'dolma@example.org' };

describe('adding a member', () => {
  let database: Database;
  let files: InMemoryFileStore;
  let portrait: Uint8Array;
  // Thursday 1 October 2026, mid-morning in Toronto.
  let now = new Date('2026-10-01T14:30:00Z');

  const service = (store: FileStore = files) =>
    new MemberService(
      new TempleAccess(new PostgresTempleRepository(database)),
      new PostgresMemberRepository(database),
      store,
      cardRenderer,
      () => now,
    );

  const tenzin = (changes: Partial<NewMemberRequest> = {}): NewMemberRequest => ({
    id: randomUUID(),
    name: 'Tenzin Dolma',
    phone: '416 555 0142',
    email: 'tenzin.dolma@example.org',
    photo: portrait,
    ...changes,
  });

  // A second temple that numbers its members JC-0001 and sells memberships
  // that run twelve months from the day they are bought.
  const addJangchub = () =>
    database.query(
      `insert into temples
         (id, name, time_zone, card_template, membership_term, membership_months,
          member_number_next, member_number_prefix, member_number_min_digits)
       values ('jangchub', 'Jangchub Choling', 'America/Vancouver', $1, 'rolling', 12,
               142, 'JC-', 4)`,
      [loseling],
    );

  const nextNumber = async (templeId = loseling) =>
    (
      await database.query<{ next: string }>(
        `select member_number_next::text as next from temples where id = $1`,
        [templeId],
      )
    )[0]?.next;

  beforeEach(async () => {
    database = await freshDatabase();
    await addToTeam(database, dolma.email, 'frontDesk');
    files = new InMemoryFileStore();
    portrait = await photo(1200, 1600);
    now = new Date('2026-10-01T14:30:00Z');
    return () => database.close();
  });

  it('gives the temple’s next membership number and a card that carries it', async () => {
    const { member, pdf } = await service().create(dolma, tenzin());

    expect(member).toMatchObject({
      templeId: loseling,
      number: '194915308',
      name: 'Tenzin Dolma',
    });
    expect(await pageCount(pdf)).toBe(2);
    const printed = (await textOn(pdf, 1)).map((run) => run.text);
    expect(printed).toEqual([
      'Drepung Loseling Canada',
      'Tenzin Dolma',
      'Valid: 2027-July-31',
      'Membership number',
      '194915308',
    ]);
  });

  it('closes up the spaces in a name, as the card prints it', async () => {
    const { member } = await service().create(dolma, tenzin({ name: 'Tenzin   Dolma' }));

    expect(member.name).toBe('Tenzin Dolma');
  });

  it('records when the membership started, was renewed and ends', async () => {
    const { member } = await service().create(dolma, tenzin());

    expect(member.joinedOn).toEqual({ year: 2026, month: 10, day: 1 });
    expect(member.renewedOn).toEqual({ year: 2026, month: 10, day: 1 });
    expect(member.expiresOn).toEqual({ year: 2027, month: 7, day: 31 });
  });

  it('saves all of it, with who added them', async () => {
    const { member } = await service().create(dolma, tenzin());

    const [saved] = await database.query(
      `select temple_id, number::text, name, email, phone, photo_key, created_by,
              joined_on::text, renewed_on::text, expires_on::text
         from members where id = $1`,
      [member.id],
    );
    expect(saved).toEqual({
      temple_id: loseling,
      number: '194915308',
      name: 'Tenzin Dolma',
      email: 'tenzin.dolma@example.org',
      phone: '416 555 0142',
      photo_key: `temples/${loseling}/members/${member.id}/photo.jpg`,
      created_by: 'uid-dolma',
      joined_on: '2026-10-01',
      renewed_on: '2026-10-01',
      expires_on: '2027-07-31',
    });
  });

  it('accepts a member with no email', async () => {
    const { member } = await service().create(dolma, tenzin({ email: '' }));

    expect(member.email).toBeNull();
  });

  it('keeps a record of the card as it was printed', async () => {
    const { member } = await service().create(dolma, tenzin());

    const cards = await database.query<{ pdf_key: string }>(
      `select number, name, valid_from::text, valid_until::text, template, photo_key, pdf_key,
              issued_by
         from member_cards where temple_id = $1 and member_id = $2`,
      [loseling, member.id],
    );
    expect(cards).toEqual([
      {
        number: '194915308',
        name: 'Tenzin Dolma',
        valid_from: '2026-10-01',
        valid_until: '2027-07-31',
        template: loseling,
        photo_key: `temples/${loseling}/members/${member.id}/photo.jpg`,
        pdf_key: expect.stringMatching(
          new RegExp(`^temples/${loseling}/members/${member.id}/cards/[0-9a-f-]{36}\\.pdf$`),
        ),
        issued_by: 'uid-dolma',
      },
    ]);
  });

  it('files the photo and the card under the temple and the member', async () => {
    const { member, pdf } = await service().create(dolma, tenzin());

    const folder = `temples/${loseling}/members/${member.id}`;
    const stored = [...files.files.entries()].map(([key, file]) => [key, file.contentType]);
    expect(stored).toEqual([
      [`${folder}/photo.jpg`, 'image/jpeg'],
      [expect.stringMatching(new RegExp(`^${folder}/cards/.+\\.pdf$`)), 'application/pdf'],
    ]);
    const [storedPhoto, storedCard] = [...files.files.values()];
    // JPEG files start with these two bytes.
    expect([...storedPhoto!.bytes.slice(0, 2)]).toEqual([0xff, 0xd8]);
    expect(Buffer.from(storedCard!.bytes).equals(Buffer.from(pdf))).toBe(true);
  });

  it('counts up from there, one member at a time', async () => {
    const first = await service().create(dolma, tenzin());
    const second = await service().create(dolma, tenzin({ name: 'Karma Dhondup' }));

    expect([first.member.number, second.member.number]).toEqual(['194915308', '194915309']);
  });

  // The in-memory database runs transactions one at a time, so this shows the
  // numbering holds for overlapping calls, not that the row lock is what holds it.
  it('gives each of several members asked for at once their own number', async () => {
    const names = ['Pema', 'Dawa', 'Nyima', 'Lhakpa', 'Phurbu', 'Pasang'];
    const members = service();

    const issued = await Promise.all(names.map((name) => members.create(dolma, tenzin({ name }))));

    const numbers = issued.map(({ member }) => member.number).sort();
    expect(numbers).toEqual([
      '194915308',
      '194915309',
      '194915310',
      '194915311',
      '194915312',
      '194915313',
    ]);
  });

  describe('asked again for a member it has already added', () => {
    it('hands back the same member and card, and takes no second number', async () => {
      const request = tenzin();
      const first = await service().create(dolma, request);

      const again = await service().create(dolma, request);

      expect(again.member).toEqual(first.member);
      expect(Buffer.from(again.pdf).equals(Buffer.from(first.pdf))).toBe(true);
      expect(await database.query(`select id from members`)).toHaveLength(1);
      expect(await database.query(`select id from member_cards`)).toHaveLength(1);
      expect(await nextNumber()).toBe('194915309');
    });

    it('does not hand one temple’s member to another', async () => {
      await addJangchub();
      await addToTeam(database, dolma.email, 'admin', 'jangchub');
      const request = tenzin({ templeId: loseling });
      await service().create(dolma, request);

      // An id is one member's everywhere, so the second temple cannot take it.
      await expect(service().create(dolma, { ...request, templeId: 'jangchub' })).rejects.toThrow(
        /members_pkey/,
      );
      expect(await nextNumber('jangchub')).toBe('142');
    });
  });

  it('takes a PNG as readily as a JPEG', async () => {
    const png = await photo(800, 600, 'png');

    const { pdf } = await service().create(dolma, tenzin({ photo: png }));

    expect(await pageCount(pdf)).toBe(2);
  });

  describe('each temple is configured, not coded', () => {
    beforeEach(async () => {
      await addJangchub();
      await addToTeam(database, dolma.email, 'admin', 'jangchub');
    });

    it('writes numbers the temple’s way', async () => {
      const { member, pdf } = await service().create(dolma, tenzin({ templeId: 'jangchub' }));

      expect(member.number).toBe('JC-0142');
      expect((await textOn(pdf, 1)).map((run) => run.text)).toContain('JC-0142');
    });

    it('runs memberships for the temple’s term', async () => {
      const { member } = await service().create(dolma, tenzin({ templeId: 'jangchub' }));

      expect(member.expiresOn).toEqual({ year: 2027, month: 10, day: 1 });
    });

    it('keeps each temple’s numbers and members to itself', async () => {
      await service().create(dolma, tenzin({ templeId: 'jangchub' }));
      const { member } = await service().create(dolma, tenzin({ templeId: loseling }));

      expect(member.number).toBe('194915308');
      expect(await nextNumber('jangchub')).toBe('143');
      const counts = await database.query(
        `select temple_id, count(*)::int as members from members group by temple_id order by 1`,
      );
      expect(counts).toEqual([
        { temple_id: loseling, members: 1 },
        { temple_id: 'jangchub', members: 1 },
      ]);
    });

    it('asks which temple when the caller works at more than one', async () => {
      await expect(service().create(dolma, tenzin())).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { templeId: 'templeRequired' } },
      });
    });
  });

  describe('who may', () => {
    it('turns away someone who is on no temple’s team, saying so', async () => {
      const stranger = { uid: 'uid-x', email: 'stranger@example.org' };

      await expect(service().create(stranger, tenzin())).rejects.toMatchObject({
        kind: 'permissionDenied',
        details: { reason: 'notOnTeam' },
      });
    });

    it('turns away a role that does not add members', async () => {
      const volunteer = { uid: 'uid-v', email: 'volunteer@example.org' };
      await addToTeam(database, volunteer.email, 'volunteer');

      await expect(service().create(volunteer, tenzin())).rejects.toMatchObject({
        kind: 'permissionDenied',
      });
    });

    it('turns away someone asking about a temple they do not work at', async () => {
      await addJangchub();

      await expect(service().create(dolma, tenzin({ templeId: 'jangchub' }))).rejects.toMatchObject(
        {
          kind: 'permissionDenied',
          details: { reason: 'notOnTeam' },
        },
      );
      expect(await nextNumber('jangchub')).toBe('142');
    });
  });

  describe('when something goes wrong', () => {
    it('refuses a name the card has no letters for, without using up a number', async () => {
      await expect(
        service().create(dolma, tenzin({ name: 'བསྟན་འཛིན་སྒྲོལ་མ།' })),
      ).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { name: 'memberNameUnsupported' } },
      });
      expect(await nextNumber()).toBe('194915308');
    });

    it('refuses a name too long for the card', async () => {
      await expect(
        service().create(
          dolma,
          tenzin({ name: 'Tenzin Lobsang Kunchok Dhondup Wangchuk Tsering' }),
        ),
      ).rejects.toMatchObject({ details: { fields: { name: 'memberNameTooLong' } } });
    });

    it('refuses a file that is not a picture, without using up a number', async () => {
      const notAPicture = Buffer.from('%PDF-1.4 this is not an image');

      await expect(service().create(dolma, tenzin({ photo: notAPicture }))).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { photo: 'photoUnreadable' } },
      });
      expect(await nextNumber()).toBe('194915308');
    });

    it('adds no member and uses no number if the card cannot be stored', async () => {
      // The photo goes in, then the file store fails on the card.
      const failing: FileStore = {
        get: (key) => files.get(key),
        put: async (key) => {
          if (key.endsWith('.pdf')) throw new Error('file store is down');
        },
      };

      await expect(service(failing).create(dolma, tenzin())).rejects.toThrow('file store is down');

      expect(await database.query(`select id from members`)).toHaveLength(0);
      expect(await database.query(`select id from member_cards`)).toHaveLength(0);
      expect(await nextNumber()).toBe('194915308');
      // The next member still gets the number that was not used.
      const { member } = await service().create(dolma, tenzin());
      expect(member.number).toBe('194915308');
    });
  });

  it('decides "today" by the temple’s clock, not the server’s', async () => {
    // Already 1 August in UTC, still 31 July in Toronto: the year end is
    // today there, so the membership runs to the next one.
    now = new Date('2027-08-01T02:00:00Z');

    const { member } = await service().create(dolma, tenzin());

    expect(member.renewedOn).toEqual({ year: 2027, month: 7, day: 31 });
    expect(member.expiresOn).toEqual({ year: 2028, month: 7, day: 31 });
  });
});

describe('the schema keeps temples apart', () => {
  let database: Database;

  beforeEach(async () => {
    database = await freshDatabase();
    return () => database.close();
  });

  it('will not attach a card to another temple’s member', async () => {
    await database.query(
      `insert into temples (id, name, time_zone, card_template, membership_term, membership_months)
       values ('other', 'Other Temple', 'UTC', 'x', 'rolling', 12)`,
    );
    const [member] = await database.query<{ id: string }>(
      `insert into members
         (temple_id, number, name, photo_key, joined_on, renewed_on, expires_on, created_by)
       values ('drepung-loseling-canada', 1, 'A', 'k', now(), now(), now(), 'u')
       returning id`,
    );

    await expect(
      database.query(
        `insert into member_cards
           (temple_id, member_id, number, name, valid_from, valid_until, template,
            photo_key, pdf_key, issued_by)
         values ('other', $1, '1', 'A', now(), now(), 'x', 'k', 'k', 'u')`,
        [member!.id],
      ),
    ).rejects.toThrow(/foreign key/);
  });
});

describe('membershipEnd', () => {
  describe('for a temple whose memberships all end on 31 July', () => {
    const end = (year: number, month: number, day: number) =>
      membershipEnd({ kind: 'fixedYearEnd', month: 7, day: 31 }, { year, month, day });

    it('is this year’s end for someone joining before it', () => {
      expect(end(2027, 3, 15)).toEqual({ year: 2027, month: 7, day: 31 });
      expect(end(2027, 7, 30)).toEqual({ year: 2027, month: 7, day: 31 });
    });

    it('is next year’s end for someone joining on or after it', () => {
      expect(end(2027, 7, 31)).toEqual({ year: 2028, month: 7, day: 31 });
      expect(end(2027, 8, 1)).toEqual({ year: 2028, month: 7, day: 31 });
      expect(end(2026, 10, 1)).toEqual({ year: 2027, month: 7, day: 31 });
    });
  });

  it('ends a year on the last day of February when the temple chose the 29th', () => {
    const end = (year: number, month: number, day: number) =>
      membershipEnd({ kind: 'fixedYearEnd', month: 2, day: 29 }, { year, month, day });

    expect(end(2026, 10, 1)).toEqual({ year: 2027, month: 2, day: 28 });
    expect(end(2027, 2, 28)).toEqual({ year: 2028, month: 2, day: 29 });
  });

  describe('for a temple whose memberships run a number of months', () => {
    const end = (months: number, year: number, month: number, day: number) =>
      membershipEnd({ kind: 'rolling', months }, { year, month, day });

    it('ends on the same day that many months on', () => {
      expect(end(12, 2026, 10, 1)).toEqual({ year: 2027, month: 10, day: 1 });
      expect(end(6, 2026, 10, 15)).toEqual({ year: 2027, month: 4, day: 15 });
    });

    it('ends on the last day of a month too short to have that day', () => {
      expect(end(1, 2027, 1, 31)).toEqual({ year: 2027, month: 2, day: 28 });
      expect(end(12, 2028, 2, 29)).toEqual({ year: 2029, month: 2, day: 28 });
    });
  });
});

describe('what members-create accepts', () => {
  const request = { id: randomUUID(), name: 'Tenzin Dolma', phone: '416 555 0142', photo: 'AAAA' };
  const accepted = (changes: Record<string, unknown> = {}) =>
    parseInput(newMemberInput, { ...request, ...changes });

  /** The fields a request with these `changes` is refused for. */
  const refused = (changes: Record<string, unknown>) => {
    try {
      accepted(changes);
    } catch (error) {
      return (error as { details: { fields: Record<string, string> } }).details.fields;
    }
    return undefined;
  };

  it('tidies what was typed', () => {
    const changes = {
      name: '  Tenzin Dolma ',
      phone: ' (416) 555-0142 ',
      email: ' Tenzin.Dolma@Example.org ',
    };

    expect(accepted(changes)).toMatchObject({
      name: 'Tenzin Dolma',
      phone: '(416) 555-0142',
      email: 'tenzin.dolma@example.org',
    });
  });

  it('lets the email be left out or empty, but not half typed', () => {
    expect(accepted().email).toBeUndefined();
    expect(accepted({ email: ' ' }).email).toBe('');
    expect(refused({ email: 'tenzin@' })).toEqual({ email: 'emailIncomplete' });
  });

  it('needs a name, and one no longer than a card could hold', () => {
    expect(refused({ name: ' ' })).toEqual({ name: 'memberNameRequired' });
    expect(refused({ name: undefined })).toEqual({ name: 'memberNameRequired' });
    expect(refused({ name: 'a'.repeat(81) })).toEqual({ name: 'memberNameTooLong' });
  });

  it('needs a phone number of ten digits, however it is punctuated', () => {
    expect(accepted({ phone: '+1 (416) 555-0142' }).phone).toBe('+1 (416) 555-0142');
    expect(refused({ phone: '555 0142' })).toEqual({ phone: 'phoneTooShort' });
    expect(refused({ phone: undefined })).toEqual({ phone: 'phoneTooShort' });
  });

  it('asks for a photo when none is sent', () => {
    expect(refused({ photo: undefined })).toEqual({ photo: 'photoRequired' });
    expect(refused({ photo: '' })).toEqual({ photo: 'photoRequired' });
  });

  it('refuses a photo that is not base64, or is larger than a camera makes', () => {
    expect(refused({ photo: 'not base64!' })).toEqual({ photo: 'photoUnreadable' });
    expect(refused({ photo: 'A'.repeat(12 * 1024 * 1024) })).toEqual({ photo: 'photoUnreadable' });
  });

  it('refuses text that no keyboard types', () => {
    const changes = { name: 'Tenzin\u0000Dolma', phone: '416 555 0142\u0000' };

    expect(refused(changes)).toEqual({ name: 'memberNameUnsupported', phone: 'phoneTooShort' });
  });

  it('names the temple as missing when it is sent empty', () => {
    expect(refused({ templeId: '' })).toEqual({ templeId: 'templeRequired' });
  });

  // The app fills in the id itself, so a bad one is its bug and has no issue name.
  it('needs the app to name the member it is adding', () => {
    expect(refused({ id: 'not-a-uuid' })).toHaveProperty('id');
    expect(refused({ id: undefined })).toHaveProperty('id');
  });
});
