import { randomUUID } from 'node:crypto';

import { beforeEach, describe, expect, it } from 'vitest';

import type { Database } from '../../../src/core/database';
import { type FileStore, InMemoryFileStore } from '../../../src/core/file-store';
import { parseInput } from '../../../src/core/validation';
import { cardRenderer } from '../../../src/features/cards';
import {
  newMemberInput,
  previewCardInput,
  updateMemberInput,
} from '../../../src/features/members/members.input';
import {
  membershipEnd,
  MemberService,
  type NewMemberRequest,
  type UpdateMemberRequest,
} from '../../../src/features/members/members.service';
import { PostgresMemberRepository } from '../../../src/features/members/postgres-member.repository';
import { PostgresTempleRepository } from '../../../src/features/temples/postgres-temple.repository';
import { TempleAccess } from '../../../src/features/temples/temple-access';
import { addToTeam, freshDatabase, loseling } from '../../support/database';
import { pageCount, textOn } from '../../support/pdf';
import { photo } from '../../support/photos';

const dolma = { uid: 'uid-dolma', email: 'dolma@example.org' };

describe('members', () => {
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

  /** Adds a member, who must not be turned away for their number. */
  const add = async (request: NewMemberRequest = tenzin(), store: FileStore = files) => {
    const result = await service(store).create(dolma, request);
    if ('taken' in result) throw new Error(`${result.taken.name} has that number.`);
    return result;
  };

  /** Changes a member, who must not be turned away for their number. */
  const change = async (request: UpdateMemberRequest) => {
    const result = await service().update(dolma, request);
    if ('taken' in result) throw new Error(`${result.taken.name} has that number.`);
    return result;
  };

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

  const count = async (table: 'members' | 'member_cards') =>
    (await database.query(`select 1 from ${table}`)).length;

  const printedOn = async (pdf: Uint8Array) => (await textOn(pdf, 1)).map((run) => run.text);

  beforeEach(async () => {
    database = await freshDatabase();
    await addToTeam(database, dolma.email, 'frontDesk');
    files = new InMemoryFileStore();
    portrait = await photo(1200, 1600);
    now = new Date('2026-10-01T14:30:00Z');
    return () => database.close();
  });

  describe('adding a member', () => {
    it('gives the temple’s next membership number and a card that carries it', async () => {
      const { member, pdf } = await add();

      expect(member).toMatchObject({
        templeId: loseling,
        number: '194915308',
        name: 'Tenzin Dolma',
      });
      expect(await pageCount(pdf)).toBe(2);
      expect(await printedOn(pdf)).toEqual([
        'Drepung Loseling Canada',
        'Tenzin Dolma',
        'Valid: 2027-July-31',
        'Membership number',
        '194915308',
      ]);
    });

    it('closes up the spaces in a name, as the card prints it', async () => {
      const { member } = await add(tenzin({ name: 'Tenzin   Dolma' }));

      expect(member.name).toBe('Tenzin Dolma');
    });

    it('records when the membership started, was renewed and ends', async () => {
      const { member } = await add();

      expect(member.joinedOn).toEqual({ year: 2026, month: 10, day: 1 });
      expect(member.renewedOn).toEqual({ year: 2026, month: 10, day: 1 });
      expect(member.expiresOn).toEqual({ year: 2027, month: 7, day: 31 });
    });

    it('saves all of it, with who added them', async () => {
      const request = tenzin();
      const { member } = await add(request);

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
        photo_key: `temples/${loseling}/members/${member.id}/cards/${request.id}.jpg`,
        created_by: 'uid-dolma',
        joined_on: '2026-10-01',
        renewed_on: '2026-10-01',
        expires_on: '2027-07-31',
      });
    });

    it('accepts a member with no email and no phone', async () => {
      const { member } = await add(tenzin({ email: '', phone: undefined }));

      expect(member.email).toBeNull();
      expect(member.phone).toBeNull();
    });

    it('keeps a record of the card as it was printed', async () => {
      const request = tenzin();
      const { member } = await add(request);

      const cards = await database.query(
        `select id, number, name, valid_from::text, valid_until::text, template, photo_key,
                pdf_key, issued_by
           from member_cards where temple_id = $1 and member_id = $2`,
        [loseling, member.id],
      );
      const card = `temples/${loseling}/members/${member.id}/cards/${request.id}`;
      expect(cards).toEqual([
        {
          id: request.id,
          number: '194915308',
          name: 'Tenzin Dolma',
          valid_from: '2026-10-01',
          valid_until: '2027-07-31',
          template: loseling,
          photo_key: `${card}.jpg`,
          pdf_key: `${card}.pdf`,
          issued_by: 'uid-dolma',
        },
      ]);
    });

    it('files the photo and the card side by side, under the temple and the member', async () => {
      const request = tenzin();
      const { member, pdf } = await add(request);

      const card = `temples/${loseling}/members/${member.id}/cards/${request.id}`;
      const stored = [...files.files.entries()].map(([key, file]) => [key, file.contentType]);
      expect(stored).toEqual([
        [`${card}.jpg`, 'image/jpeg'],
        [`${card}.pdf`, 'application/pdf'],
      ]);
      const [storedPhoto, storedCard] = [...files.files.values()];
      // JPEG files start with these two bytes.
      expect([...storedPhoto!.bytes.slice(0, 2)]).toEqual([0xff, 0xd8]);
      expect(Buffer.from(storedCard!.bytes).equals(Buffer.from(pdf))).toBe(true);
    });

    it('counts up from there, one member at a time', async () => {
      const first = await add();
      const second = await add(tenzin({ name: 'Karma Dhondup' }));

      expect([first.member.number, second.member.number]).toEqual(['194915308', '194915309']);
    });

    // The in-memory database runs transactions one at a time, so this shows the
    // numbering holds for overlapping calls, not that the row lock is what holds it.
    it('gives each of several members asked for at once their own number', async () => {
      const names = ['Pema', 'Dawa', 'Nyima', 'Lhakpa', 'Phurbu', 'Pasang'];

      const issued = await Promise.all(names.map((name) => add(tenzin({ name }))));

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
        const first = await add(request);

        const again = await add(request);

        expect(again.member).toEqual(first.member);
        expect(Buffer.from(again.pdf).equals(Buffer.from(first.pdf))).toBe(true);
        expect(await count('members')).toBe(1);
        expect(await count('member_cards')).toBe(1);
        expect(await nextNumber()).toBe('194915309');
      });

      // A retry after a timeout can arrive while the first is still at work.
      it('twice at once, adds one member whose card carries their number', async () => {
        const request = tenzin();

        const [first, second] = await Promise.all([add(request), add(request)]);

        expect(second.member).toEqual(first.member);
        expect(await count('members')).toBe(1);
        expect(await count('member_cards')).toBe(1);
        expect(await nextNumber()).toBe('194915309');
        const onFile = await service().card(dolma, { memberId: first.member.id });
        expect(await printedOn(onFile.pdf)).toContain(first.member.number);
      });

      it('twice at once with a typed number, is not told its own number is taken', async () => {
        const request = tenzin({ number: '500' });

        const [first, second] = await Promise.all([add(request), add(request)]);

        expect(second.member).toEqual(first.member);
        expect(await count('members')).toBe(1);
      });

      it('does not hand one temple’s member to another', async () => {
        await addJangchub();
        await addToTeam(database, dolma.email, 'admin', 'jangchub');
        const request = tenzin({ templeId: loseling });
        await add(request);

        // An id is one member's everywhere, so the second temple cannot take it.
        await expect(
          service().create(dolma, { ...request, templeId: 'jangchub' }),
        ).rejects.toThrow();
        expect(await service().list(dolma, 'jangchub')).toEqual([]);
        expect(await nextNumber('jangchub')).toBe('142');
      });
    });

    it('takes a PNG as readily as a JPEG', async () => {
      const png = await photo(800, 600, 'png');

      const { pdf } = await add(tenzin({ photo: png }));

      expect(await pageCount(pdf)).toBe(2);
    });

    describe('each temple is configured, not coded', () => {
      beforeEach(async () => {
        await addJangchub();
        await addToTeam(database, dolma.email, 'admin', 'jangchub');
      });

      it('writes numbers the temple’s way', async () => {
        const { member, pdf } = await add(tenzin({ templeId: 'jangchub' }));

        expect(member.number).toBe('JC-0142');
        expect(await printedOn(pdf)).toContain('JC-0142');
      });

      it('runs memberships for the temple’s term', async () => {
        const { member } = await add(tenzin({ templeId: 'jangchub' }));

        expect(member.expiresOn).toEqual({ year: 2027, month: 10, day: 1 });
      });

      it('keeps each temple’s numbers and members to itself', async () => {
        await add(tenzin({ templeId: 'jangchub' }));
        const { member } = await add(tenzin({ templeId: loseling }));

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

        await expect(
          service().create(dolma, tenzin({ templeId: 'jangchub' })),
        ).rejects.toMatchObject({
          kind: 'permissionDenied',
          details: { reason: 'notOnTeam' },
        });
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

        await expect(service().create(dolma, tenzin({ photo: notAPicture }))).rejects.toMatchObject(
          {
            kind: 'invalid',
            details: { fields: { photo: 'photoUnreadable' } },
          },
        );
        expect(await nextNumber()).toBe('194915308');
      });

      it('adds no member and uses no number if the card cannot be stored', async () => {
        // The photo goes in, then the file store fails on the card.
        const failing: FileStore = {
          get: (key) => files.get(key),
          put: async (key) => {
            if (key.endsWith('.pdf')) throw new Error('file store is down');
          },
          urlFor: () => files.urlFor(),
        };

        await expect(service(failing).create(dolma, tenzin())).rejects.toThrow(
          'file store is down',
        );

        expect(await count('members')).toBe(0);
        expect(await count('member_cards')).toBe(0);
        expect(await nextNumber()).toBe('194915308');
        // The next member still gets the number that was not used.
        const { member } = await add();
        expect(member.number).toBe('194915308');
      });
    });

    it('decides "today" by the temple’s clock, not the server’s', async () => {
      // Already 1 August in UTC, still 31 July in Toronto: the year end is
      // today there, so the membership runs to the next one.
      now = new Date('2027-08-01T02:00:00Z');

      const { member } = await add();

      expect(member.renewedOn).toEqual({ year: 2027, month: 7, day: 31 });
      expect(member.expiresOn).toEqual({ year: 2028, month: 7, day: 31 });
    });
  });

  describe('a number typed by hand', () => {
    it('is the member’s number, and the count stays where it was', async () => {
      const { member, pdf } = await add(tenzin({ number: '500' }));

      expect(member.number).toBe('500');
      expect(await printedOn(pdf)).toContain('500');
      expect(await nextNumber()).toBe('194915308');
    });

    it('is written the temple’s way', async () => {
      await addJangchub();
      await addToTeam(database, dolma.email, 'admin', 'jangchub');

      const { member } = await add(tenzin({ templeId: 'jangchub', number: '7' }));

      expect(member.number).toBe('JC-0007');
    });

    it('is skipped when the count reaches it', async () => {
      await add(tenzin({ name: 'Pema', number: '194915309' }));

      const next = await add(tenzin({ name: 'Dawa' }));
      const afterThat = await add(tenzin({ name: 'Nyima' }));

      expect([next.member.number, afterThat.member.number]).toEqual(['194915308', '194915310']);
      expect(await nextNumber()).toBe('194915311');
    });

    describe('that someone already holds', () => {
      it('adds nobody and says who has it', async () => {
        await add();

        const result = await service().create(
          dolma,
          tenzin({ name: 'Karma Dhondup', number: '194915308' }),
        );

        expect(result).toMatchObject({ taken: { name: 'Tenzin Dolma', number: '194915308' } });
        expect(await count('members')).toBe(1);
        expect(await count('member_cards')).toBe(1);
        // Nothing of the person turned away is kept.
        expect(files.files.size).toBe(2);
      });

      it('does not clash with the same number at another temple', async () => {
        await addJangchub();
        await addToTeam(database, dolma.email, 'admin', 'jangchub');
        await add(tenzin({ templeId: 'jangchub', number: '9' }));

        const { member } = await add(tenzin({ templeId: loseling, number: '9' }));

        expect(member.number).toBe('9');
      });

      it('is given to the new person when replacing: same record, new details and card', async () => {
        const first = await add();
        // Eight months on, in the next membership year.
        now = new Date('2027-08-15T14:30:00Z');

        const karma = tenzin({
          name: 'Karma Dhondup',
          phone: '',
          email: 'karma@example.org',
          number: '194915308',
          replace: true,
        });
        const { member, pdf } = await add(karma);

        expect(member).toEqual({
          id: first.member.id,
          templeId: loseling,
          number: '194915308',
          name: 'Karma Dhondup',
          email: 'karma@example.org',
          phone: null,
          // The card and the photo are the new person's.
          photoKey: `temples/${loseling}/members/${first.member.id}/cards/${karma.id}.jpg`,
          cardId: karma.id,
          // They keep the day the record was opened, and start a membership today.
          joinedOn: { year: 2026, month: 10, day: 1 },
          renewedOn: { year: 2027, month: 8, day: 15 },
          expiresOn: { year: 2028, month: 7, day: 31 },
        });
        expect(await printedOn(pdf)).toEqual(
          expect.arrayContaining(['Karma Dhondup', 'Valid: 2028-July-31', '194915308']),
        );
        expect(await count('members')).toBe(1);
        expect(await service().list(dolma)).toEqual([member]);
      });

      it('keeps the card that was replaced on record', async () => {
        const first = await add();

        const karma = tenzin({ name: 'Karma Dhondup', number: '194915308', replace: true });
        await add(karma);

        const cards = await database.query(
          `select id, name, photo_key from member_cards order by issued_at, name desc`,
        );
        const folder = `temples/${loseling}/members/${first.member.id}/cards`;
        expect(cards).toEqual(
          expect.arrayContaining([
            expect.objectContaining({ name: 'Tenzin Dolma' }),
            { id: karma.id, name: 'Karma Dhondup', photo_key: `${folder}/${karma.id}.jpg` },
          ]),
        );
        expect(cards).toHaveLength(2);
        const [saved] = await database.query(`select photo_key from members`);
        expect(saved).toEqual({ photo_key: `${folder}/${karma.id}.jpg` });
      });

      it('asked again, replaces once', async () => {
        await add();
        const karma = tenzin({ name: 'Karma Dhondup', number: '194915308', replace: true });
        const first = await add(karma);

        const again = await add(karma);

        expect(again.member).toEqual(first.member);
        expect(Buffer.from(again.pdf).equals(Buffer.from(first.pdf))).toBe(true);
        expect(await count('member_cards')).toBe(2);
      });

      it('asked twice at once, replaces once', async () => {
        await add();
        const karma = tenzin({ name: 'Karma Dhondup', number: '194915308', replace: true });

        const [first, second] = await Promise.all([add(karma), add(karma)]);

        expect(second.member).toEqual(first.member);
        expect(await count('members')).toBe(1);
        expect(await count('member_cards')).toBe(2);
      });

      it('replacing a number nobody holds simply adds the member', async () => {
        const { member } = await add(tenzin({ number: '77', replace: true }));

        expect(member.number).toBe('77');
        expect(await count('members')).toBe(1);
      });
    });
  });

  describe('a member whose card was made by hand', () => {
    // The temple's Canva cards: bought for the year to 31 July 2026.
    const handMade = {
      joinedOn: { year: 2025, month: 8, day: 1 },
      renewedOn: { year: 2025, month: 8, day: 1 },
      expiresOn: { year: 2026, month: 7, day: 31 },
    };

    const card = (changes: Partial<NewMemberRequest> = {}) => ({
      ...tenzin({ email: undefined, phone: undefined }),
      number: '194915185',
      ...changes,
    });

    const addExisting = async (request = card()) => {
      const result = await service().addExisting(dolma, request, handMade);
      if ('taken' in result) throw new Error(`${result.taken.name} has that number.`);
      return result;
    };

    it('is added with its number and dates, on a card that carries them', async () => {
      const { member, pdf } = await addExisting();

      expect(member).toMatchObject({ number: '194915185', email: null, phone: null, ...handMade });
      expect(await printedOn(pdf)).toEqual([
        'Drepung Loseling Canada',
        'Tenzin Dolma',
        'Valid: 2026-July-31',
        'Membership number',
        '194915185',
      ]);
    });

    it('keeps a record of the card with those dates', async () => {
      const request = card();
      const { member } = await addExisting(request);

      const [saved] = await database.query(
        `select id, number, valid_from::text, valid_until::text, issued_by
           from member_cards where temple_id = $1 and member_id = $2`,
        [loseling, member.id],
      );
      expect(saved).toEqual({
        id: request.id,
        number: '194915185',
        valid_from: '2025-08-01',
        valid_until: '2026-07-31',
        issued_by: 'uid-dolma',
      });
    });

    it('leaves the count alone, so the next new member gets the next number', async () => {
      await addExisting(card({ number: '194915307' }));

      const { member } = await add();

      expect(member.number).toBe('194915308');
    });

    it('asked again, adds nobody new', async () => {
      const request = card();
      const first = await addExisting(request);

      const again = await addExisting(request);

      expect(again.member).toEqual(first.member);
      expect(await count('members')).toBe(1);
      expect(await count('member_cards')).toBe(1);
    });

    it('is turned away when someone holds its number, even asked to replace them', async () => {
      await add(tenzin({ number: '194915185' }));

      const result = await service().addExisting(
        dolma,
        card({ name: 'Karma Dhondup', replace: true }),
        handMade,
      );

      expect(result).toMatchObject({ taken: { name: 'Tenzin Dolma' } });
      expect(await count('members')).toBe(1);
    });

    it('is previewed with the card’s last day', async () => {
      const { pdf } = await service().preview(dolma, {
        name: 'Tenzin Dolma',
        photo: portrait,
        number: '194915185',
        validUntil: handMade.expiresOn,
      });

      expect(await printedOn(pdf)).toContain('Valid: 2026-July-31');
    });
  });

  describe('previewing a card', () => {
    const previewOf = (changes: Record<string, unknown> = {}) =>
      service().preview(dolma, { name: 'Tenzin Dolma', photo: portrait, ...changes });

    it('draws the card with the next number, and saves nothing', async () => {
      const { number, pdf } = await previewOf();

      expect(number).toEqual({ digits: '194915308', label: '194915308' });
      expect(await pageCount(pdf)).toBe(2);
      expect(await printedOn(pdf)).toEqual([
        'Drepung Loseling Canada',
        'Tenzin Dolma',
        'Valid: 2027-July-31',
        'Membership number',
        '194915308',
      ]);
      expect(await count('members')).toBe(0);
      expect(files.files.size).toBe(0);
      expect(await nextNumber()).toBe('194915308');
    });

    it('shows the number a new member will really get', async () => {
      await add(tenzin({ number: '194915308' }));

      expect((await previewOf()).number.digits).toBe('194915309');
    });

    it('carries a number typed by hand, written the temple’s way', async () => {
      await addJangchub();
      await addToTeam(database, dolma.email, 'admin', 'jangchub');

      const { number, pdf } = await previewOf({ templeId: 'jangchub', number: '7' });

      expect(number).toEqual({ digits: '7', label: 'JC-0007' });
      expect(await printedOn(pdf)).toContain('JC-0007');
    });

    it('needs a photo for a new member', async () => {
      await expect(previewOf({ photo: undefined })).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { photo: 'photoRequired' } },
      });
    });

    it('refuses what the card cannot print, as adding would', async () => {
      await expect(previewOf({ name: 'བསྟན་འཛིན་' })).rejects.toMatchObject({
        details: { fields: { name: 'memberNameUnsupported' } },
      });
      await expect(previewOf({ photo: Buffer.from('not a picture') })).rejects.toMatchObject({
        details: { fields: { photo: 'photoUnreadable' } },
      });
    });

    it('for a member on file, keeps their number, photo and dates', async () => {
      const { member } = await add();
      now = new Date('2027-01-10T14:30:00Z');

      const { number, pdf } = await service().preview(dolma, {
        memberId: member.id,
        name: 'Tenzin D. Sherpa',
      });

      expect(number.digits).toBe('194915308');
      expect(await printedOn(pdf)).toEqual(
        expect.arrayContaining(['Tenzin D. Sherpa', 'Valid: 2027-July-31', '194915308']),
      );
      expect(await count('member_cards')).toBe(1);
    });

    it('for a member on file, draws a new photo or number without saving either', async () => {
      const { member } = await add();
      const before = files.files.size;

      const preview = await service().preview(dolma, {
        memberId: member.id,
        name: 'Tenzin Dolma',
        photo: await photo(900, 1200),
        number: '777',
      });

      expect(preview.number).toEqual({ digits: '777', label: '777' });
      expect(await printedOn(preview.pdf)).toContain('777');
      expect(files.files.size).toBe(before);
      expect((await service().list(dolma))[0]?.number).toBe(member.number);
    });

    it('says so when there is no such member', async () => {
      await expect(
        service().preview(dolma, { memberId: randomUUID(), name: 'Tenzin Dolma' }),
      ).rejects.toMatchObject({ kind: 'notFound' });
    });

    it('turns away a role that does not add members', async () => {
      const accountant = { uid: 'uid-a', email: 'accountant@example.org' };
      await addToTeam(database, accountant.email, 'accountant');

      await expect(
        service().preview(accountant, { name: 'Tenzin Dolma', photo: portrait }),
      ).rejects.toMatchObject({ kind: 'permissionDenied' });
    });
  });

  describe('changing a member', () => {
    let memberId: string;
    let firstCard: Uint8Array;

    const changes = (values: Partial<UpdateMemberRequest> = {}): UpdateMemberRequest => ({
      id: randomUUID(),
      memberId,
      name: 'Tenzin Dolma',
      phone: '416 555 0142',
      email: 'tenzin.dolma@example.org',
      ...values,
    });

    beforeEach(async () => {
      const { member, pdf } = await add();
      memberId = member.id;
      firstCard = pdf;
    });

    it('changes how to reach them without printing a new card', async () => {
      const { member, pdf } = await change(changes({ phone: '+1 647 555 0188', email: '' }));

      expect(member).toMatchObject({ id: memberId, phone: '+1 647 555 0188', email: null });
      expect(await count('member_cards')).toBe(1);
      expect(Buffer.from(pdf).equals(Buffer.from(firstCard))).toBe(true);
      expect(await service().list(dolma)).toEqual([member]);
    });

    it('prints a new card for a new name, with the same photo, number and dates', async () => {
      now = new Date('2027-01-10T14:30:00Z');
      const request = changes({ name: 'Tenzin D. Sherpa' });

      const { member, pdf } = await change(request);

      expect(member).toMatchObject({
        name: 'Tenzin D. Sherpa',
        number: '194915308',
        renewedOn: { year: 2026, month: 10, day: 1 },
        expiresOn: { year: 2027, month: 7, day: 31 },
      });
      expect(await printedOn(pdf)).toEqual(
        expect.arrayContaining(['Tenzin D. Sherpa', 'Valid: 2027-July-31', '194915308']),
      );
      const cards = await database.query<{ id: string; photo_key: string; pdf_key: string }>(
        `select id, photo_key, pdf_key, valid_from::text, valid_until::text from member_cards
          order by issued_at`,
      );
      expect(cards).toHaveLength(2);
      const reissued = cards.find((card) => card.id === request.id);
      expect(reissued).toMatchObject({
        valid_from: '2026-10-01',
        valid_until: '2027-07-31',
        pdf_key: `temples/${loseling}/members/${memberId}/cards/${request.id}.pdf`,
      });
      // The photo on the new card is the one already on file.
      expect(new Set(cards.map((card) => card.photo_key)).size).toBe(1);
    });

    it('prints a new card for a new photo, and keeps that photo', async () => {
      const request = changes({ photo: await photo(600, 800, 'png') });

      await change(request);

      const [saved] = await database.query(`select photo_key from members`);
      expect(saved).toEqual({
        photo_key: `temples/${loseling}/members/${memberId}/cards/${request.id}.jpg`,
      });
      expect(await count('member_cards')).toBe(2);
    });

    it('prints a new card for a new number, if nobody holds it', async () => {
      const { member, pdf } = await change(changes({ number: '42' }));

      expect(member.number).toBe('42');
      expect(await printedOn(pdf)).toContain('42');
      expect(await count('member_cards')).toBe(2);
    });

    it('leaves everything as it was if the new number is someone else’s', async () => {
      await add(tenzin({ name: 'Karma Dhondup' }));

      const result = await service().update(
        dolma,
        changes({ name: 'Tenzin D. Sherpa', number: '194915309' }),
      );

      expect(result).toMatchObject({ taken: { name: 'Karma Dhondup', number: '194915309' } });
      const names = await database.query(`select name, number::text from members order by number`);
      expect(names).toEqual([
        { name: 'Tenzin Dolma', number: '194915308' },
        { name: 'Karma Dhondup', number: '194915309' },
      ]);
      expect(await count('member_cards')).toBe(2);
    });

    it('does not see a member’s own number as taken', async () => {
      const { member } = await change(changes({ number: '194915308', phone: '' }));

      expect(member).toMatchObject({ number: '194915308', phone: null });
      expect(await count('member_cards')).toBe(1);
    });

    it('asked again, prints one new card', async () => {
      const request = changes({ name: 'Tenzin D. Sherpa' });
      const first = await change(request);

      const again = await change(request);

      expect(again.member).toEqual(first.member);
      expect(Buffer.from(again.pdf).equals(Buffer.from(first.pdf))).toBe(true);
      expect(await count('member_cards')).toBe(2);
    });

    it('asked twice at once, prints one new card', async () => {
      const request = changes({ name: 'Tenzin D. Sherpa', photo: await photo(900, 1200) });

      const [first, second] = await Promise.all([change(request), change(request)]);

      expect(second.member).toEqual(first.member);
      expect(Buffer.from(second.pdf).equals(Buffer.from(first.pdf))).toBe(true);
      expect(await count('member_cards')).toBe(2);
    });

    it('holds the card printed last, whichever change began first', async () => {
      const first = await change(changes({ name: 'Tenzin D. Sherpa' }));
      const second = await change(changes({ name: 'Tenzin Dolma Sherpa' }));

      const onFile = await service().card(dolma, { memberId });

      expect(first.member.cardId).not.toBe(second.member.cardId);
      expect(onFile.member.cardId).toBe(second.member.cardId);
      expect(await printedOn(onFile.pdf)).toContain('Tenzin Dolma Sherpa');
    });

    it('refuses a photo that is not a picture, and changes nothing', async () => {
      const notAPicture = new TextEncoder().encode('not a picture');

      await expect(
        change(changes({ name: 'Tenzin D.', photo: notAPicture })),
      ).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { photo: 'photoUnreadable' } },
      });
      expect((await service().list(dolma))[0]?.name).toBe('Tenzin Dolma');
      expect(await count('member_cards')).toBe(1);
    });

    it('refuses a name the card cannot print', async () => {
      await expect(service().update(dolma, changes({ name: 'བསྟན་འཛིན་' }))).rejects.toMatchObject({
        details: { fields: { name: 'memberNameUnsupported' } },
      });
    });

    it('says so when there is no such member, here or at this temple', async () => {
      await expect(
        service().update(dolma, changes({ memberId: randomUUID() })),
      ).rejects.toMatchObject({ kind: 'notFound' });

      await addJangchub();
      await addToTeam(database, dolma.email, 'admin', 'jangchub');
      await expect(
        service().update(dolma, changes({ templeId: 'jangchub' })),
      ).rejects.toMatchObject({ kind: 'notFound' });
    });

    it('turns away a role that does not add members', async () => {
      const accountant = { uid: 'uid-a', email: 'accountant@example.org' };
      await addToTeam(database, accountant.email, 'accountant');

      await expect(service().update(accountant, changes())).rejects.toMatchObject({
        kind: 'permissionDenied',
      });
    });
  });

  describe('the member list', () => {
    it('is the temple’s members, the newest first', async () => {
      const tenzinAdded = await add();
      const karmaAdded = await add(tenzin({ name: 'Karma Dhondup', email: '', phone: '' }));

      expect(await service().list(dolma)).toEqual([karmaAdded.member, tenzinAdded.member]);
    });

    it('says which card each member holds, so the app knows when to fetch a new one', async () => {
      const request = tenzin();
      const added = await add(request);
      expect(added.member.cardId).toBe(request.id);
      expect((await service().list(dolma))[0]?.cardId).toBe(request.id);

      // A change that prints nothing leaves them holding the same card.
      const contact = { id: randomUUID(), memberId: added.member.id, name: 'Tenzin Dolma' };
      expect((await change({ ...contact, phone: '+1 647 555 0188' })).member.cardId).toBe(
        request.id,
      );

      const renamed = { id: randomUUID(), memberId: added.member.id, name: 'Tenzin D. Sherpa' };
      expect((await change(renamed)).member.cardId).toBe(renamed.id);
      expect((await service().list(dolma))[0]?.cardId).toBe(renamed.id);
    });

    it('asks the file store for a link to a member’s photo that lasts a week', async () => {
      const asked: [string, number][] = [];
      const linking: FileStore = {
        get: (key) => files.get(key),
        put: (key, bytes, contentType) => files.put(key, bytes, contentType),
        urlFor: async (key, seconds) => {
          asked.push([key, seconds]);
          return `https://files.example/${key}?signed`;
        },
      };
      const request = tenzin();
      const { member } = await add(request, linking);

      const url = await service(linking).photoUrl(member);

      const key = `temples/${loseling}/members/${member.id}/cards/${request.id}.jpg`;
      expect(member.photoKey).toBe(key);
      expect(url).toBe(`https://files.example/${key}?signed`);
      expect(asked).toEqual([[key, 7 * 24 * 60 * 60]]);
    });

    it('has no link to give when files are kept only in memory', async () => {
      const { member } = await add();

      expect(await service().photoUrl(member)).toBeNull();
    });

    it('is empty for a temple with no members yet', async () => {
      expect(await service().list(dolma)).toEqual([]);
    });

    it('never shows another temple’s members', async () => {
      await addJangchub();
      await addToTeam(database, dolma.email, 'admin', 'jangchub');
      await add(tenzin({ templeId: 'jangchub' }));
      const here = await add(tenzin({ templeId: loseling, name: 'Karma Dhondup' }));

      expect(await service().list(dolma, loseling)).toEqual([here.member]);
    });

    it('is open to the office, but not to volunteers', async () => {
      const accountant = { uid: 'uid-a', email: 'accountant@example.org' };
      const volunteer = { uid: 'uid-v', email: 'volunteer@example.org' };
      await addToTeam(database, accountant.email, 'accountant');
      await addToTeam(database, volunteer.email, 'volunteer');

      await expect(service().list(accountant)).resolves.toEqual([]);
      await expect(service().list(volunteer)).rejects.toMatchObject({ kind: 'permissionDenied' });
    });
  });

  describe('a member’s card', () => {
    it('is the card they were last issued', async () => {
      const { member } = await add();
      const reissued = await change({
        id: randomUUID(),
        memberId: member.id,
        name: 'Tenzin D. Sherpa',
      });

      const card = await service().card(dolma, { memberId: member.id });

      expect(card.member).toEqual(reissued.member);
      expect(Buffer.from(card.pdf).equals(Buffer.from(reissued.pdf))).toBe(true);
    });

    it('is not handed to another temple', async () => {
      await addJangchub();
      await addToTeam(database, dolma.email, 'admin', 'jangchub');
      const { member } = await add(tenzin({ templeId: loseling }));

      await expect(
        service().card(dolma, { memberId: member.id, templeId: 'jangchub' }),
      ).rejects.toMatchObject({ kind: 'notFound' });
    });

    it('is open to the office, but not to volunteers', async () => {
      const accountant = { uid: 'uid-a', email: 'accountant@example.org' };
      const volunteer = { uid: 'uid-v', email: 'volunteer@example.org' };
      await addToTeam(database, accountant.email, 'accountant');
      await addToTeam(database, volunteer.email, 'volunteer');
      const { member } = await add();

      await expect(service().card(accountant, { memberId: member.id })).resolves.toMatchObject({
        member: { id: member.id },
      });
      await expect(service().card(volunteer, { memberId: member.id })).rejects.toMatchObject({
        kind: 'permissionDenied',
      });
    });

    it('says so when there is no such member', async () => {
      await expect(service().card(dolma, { memberId: randomUUID() })).rejects.toMatchObject({
        kind: 'notFound',
      });
    });
  });

  describe('a temple with the standard card', () => {
    beforeEach(async () => {
      await database.query(
        `insert into temples (id, name, time_zone, card_template, membership_term,
                              membership_months)
         values ('drolma-ling', 'Drolma Ling Centre', 'America/Vancouver', 'standard',
                 'rolling', 12)`,
      );
      await addToTeam(database, dolma.email, 'admin', 'drolma-ling');
    });

    it('prints its own name on the card, and numbers from one', async () => {
      const { member, pdf } = await add(tenzin({ templeId: 'drolma-ling' }));

      expect(member.number).toBe('1');
      expect(await printedOn(pdf)).toEqual([
        'Drolma Ling Centre',
        'Tenzin Dolma',
        'Valid until 1 October 2027',
        'Membership number',
        '1',
      ]);
    });
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

describe('what the member functions accept', () => {
  const request = { id: randomUUID(), name: 'Tenzin Dolma', phone: '416 555 0142', photo: 'AAAA' };
  const accepted = (changes: Record<string, unknown> = {}) =>
    parseInput(newMemberInput, { ...request, ...changes });

  /** The fields a request is refused for, by `schema`. */
  const refusedBy = (schema: Parameters<typeof parseInput>[0], data: unknown) => {
    try {
      parseInput(schema, data);
    } catch (error) {
      return (error as { details: { fields: Record<string, string> } }).details.fields;
    }
    return undefined;
  };
  const refused = (changes: Record<string, unknown>) =>
    refusedBy(newMemberInput, { ...request, ...changes });

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

  it('lets the email be left out or empty, but not half typed or endless', () => {
    expect(accepted().email).toBeUndefined();
    expect(accepted({ email: ' ' }).email).toBe('');
    expect(refused({ email: 'tenzin@' })).toEqual({ email: 'emailIncomplete' });
    expect(refused({ email: `${'t'.repeat(250)}@example.org` })).toEqual({
      email: 'emailIncomplete',
    });
  });

  it('needs a name, and one no longer than a card could hold', () => {
    expect(refused({ name: ' ' })).toEqual({ name: 'memberNameRequired' });
    expect(refused({ name: undefined })).toEqual({ name: 'memberNameRequired' });
    expect(refused({ name: 'a'.repeat(81) })).toEqual({ name: 'memberNameTooLong' });
  });

  it('lets the phone be left out or empty, but not cut short', () => {
    expect(accepted({ phone: undefined }).phone).toBeUndefined();
    expect(accepted({ phone: ' ' }).phone).toBe('');
    expect(accepted({ phone: '+1 (416) 555-0142' }).phone).toBe('+1 (416) 555-0142');
    expect(refused({ phone: '555 0142' })).toEqual({ phone: 'phoneTooShort' });
    expect(refused({ phone: '+1 416 555 0142 0142 0142' })).toEqual({ phone: 'phoneTooLong' });
    expect(refused({ phone: 416 })).toEqual({ phone: 'phoneTooShort' });
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

  it('takes a number typed by hand as digits above zero, whatever zeros lead', () => {
    expect(accepted().number).toBeUndefined();
    expect(accepted({ number: ' 0142 ' }).number).toBe('142');
    expect(accepted({ number: '194915308' }).number).toBe('194915308');
    const endless = `${'0'.repeat(40)}1`;
    for (const number of ['', '0', '000', 'JC-0142', '12.5', '-3', '1'.repeat(16), endless, 142]) {
      expect(refused({ number }), `${number}`).toEqual({ number: 'memberNumberInvalid' });
    }
  });

  it('replaces only when told to, in so many words', () => {
    expect(accepted().replace).toBeUndefined();
    expect(accepted({ replace: true }).replace).toBe(true);
    expect(refused({ replace: 'yes' })).toHaveProperty('replace');
  });

  it('names the temple as missing when it is sent empty, or is no temple’s id', () => {
    expect(refused({ templeId: '' })).toEqual({ templeId: 'templeRequired' });
    expect(refused({ templeId: 'x'.repeat(61) })).toEqual({ templeId: 'templeRequired' });
  });

  it('files a request that is no object at all under the request itself', () => {
    expect(refusedBy(newMemberInput, null)).toHaveProperty('request');
  });

  // The app fills in the id itself, so a bad one is its bug and has no issue name.
  it('needs the app to name the member it is adding', () => {
    expect(refused({ id: 'not-a-uuid' })).toHaveProperty('id');
    expect(refused({ id: undefined })).toHaveProperty('id');
  });

  it('previews a member on file without being sent their photo again', () => {
    const preview = { memberId: randomUUID(), name: 'Tenzin Dolma' };

    expect(parseInput(previewCardInput, preview)).toEqual(preview);
    expect(refusedBy(previewCardInput, { name: ' ', photo: '!', number: 'x' })).toEqual({
      name: 'memberNameRequired',
      photo: 'photoUnreadable',
      number: 'memberNumberInvalid',
    });
  });

  it('changes a member by id, with the same rules for what is typed', () => {
    const change = { id: randomUUID(), memberId: randomUUID(), name: 'Tenzin Dolma' };

    expect(parseInput(updateMemberInput, change)).toEqual(change);
    expect(refusedBy(updateMemberInput, { ...change, memberId: undefined })).toHaveProperty(
      'memberId',
    );
    expect(
      refusedBy(updateMemberInput, { ...change, phone: '555', email: 'tenzin@', number: '0' }),
    ).toEqual({
      phone: 'phoneTooShort',
      email: 'emailIncomplete',
      number: 'memberNumberInvalid',
    });
  });
});
