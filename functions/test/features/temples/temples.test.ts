import { randomUUID } from 'node:crypto';

import sharp from 'sharp';
import { beforeEach, describe, expect, it } from 'vitest';

import type { Database } from '../../../src/core/database';
import { InMemoryFileStore } from '../../../src/core/file-store';
import { parseInput } from '../../../src/core/validation';
import { cardRenderer, templeNameProblem } from '../../../src/features/cards';
import { MemberService } from '../../../src/features/members/members.service';
import { PostgresMemberRepository } from '../../../src/features/members/postgres-member.repository';
import type { Accounts } from '../../../src/features/temples/accounts';
import { PostgresTempleRepository } from '../../../src/features/temples/postgres-temple.repository';
import { TempleAccess } from '../../../src/features/temples/temple-access';
import {
  newTempleInput,
  templeAdminInput,
  templeFeaturesInput,
  templeLogoInput,
} from '../../../src/features/temples/temples.input';
import {
  idFromName,
  type NewTempleRequest,
  TempleService,
} from '../../../src/features/temples/temples.service';
import { addToTeam, freshDatabase, loseling } from '../../support/database';
import { textOn } from '../../support/pdf';
import { photo } from '../../support/photos';

const lama = { uid: 'uid-lama', email: 'lama.karma@drolmaling.ca' };

/** Notes who was given an account, in place of Firebase Authentication. */
class RecordingAccounts implements Accounts {
  readonly ensured: string[] = [];

  async ensure(email: string): Promise<void> {
    this.ensured.push(email);
  }
}

describe('temples', () => {
  let database: Database;
  let files: InMemoryFileStore;
  let accounts: RecordingAccounts;
  let repository: PostgresTempleRepository;
  let temples: TempleService;
  let access: TempleAccess;

  const drolmaLing = (changes: Partial<NewTempleRequest> = {}): NewTempleRequest => ({
    name: 'Drolma Ling Centre',
    description: 'Kagyu tradition · Vancouver',
    timeZone: 'America/Vancouver',
    cardTemplate: 'standard',
    membership: { kind: 'rolling', months: 12 },
    memberNumber: { next: 1, prefix: '', minDigits: 0 },
    ...changes,
  });

  const team = (templeId: string) =>
    database.query(`select email, role from temple_staff where temple_id = $1 order by email`, [
      templeId,
    ]);

  beforeEach(async () => {
    database = await freshDatabase();
    files = new InMemoryFileStore();
    accounts = new RecordingAccounts();
    repository = new PostgresTempleRepository(database);
    access = new TempleAccess(repository);
    temples = new TempleService(repository, access, files, accounts, templeNameProblem);
    return () => database.close();
  });

  describe('registering one', () => {
    it('makes its id from its name, and saves what was sent', async () => {
      const temple = await temples.create(drolmaLing());

      expect(temple).toEqual({
        id: 'drolma-ling-centre',
        name: 'Drolma Ling Centre',
        description: 'Kagyu tradition · Vancouver',
        timeZone: 'America/Vancouver',
        cardTemplate: 'standard',
        letterTemplate: null,
        membershipTerm: { kind: 'rolling', months: 12 },
        logoKey: null,
        features: ['home.addMember', 'tab.members'],
      });
      const [saved] = await database.query(
        `select name, description, time_zone, card_template, membership_term, membership_months,
                member_number_next::text, member_number_prefix, member_number_min_digits, logo_key
           from temples where id = 'drolma-ling-centre'`,
      );
      expect(saved).toEqual({
        name: 'Drolma Ling Centre',
        description: 'Kagyu tradition · Vancouver',
        time_zone: 'America/Vancouver',
        card_template: 'standard',
        membership_term: 'rolling',
        membership_months: 12,
        member_number_next: '1',
        member_number_prefix: '',
        member_number_min_digits: 0,
        logo_key: null,
      });
    });

    it('takes the id it is sent instead', async () => {
      const temple = await temples.create(drolmaLing({ id: 'drolma-ling-vancouver' }));

      expect(temple.id).toBe('drolma-ling-vancouver');
    });

    it('saves a membership year that ends on a fixed day', async () => {
      await temples.create(drolmaLing({ membership: { kind: 'fixedYearEnd', month: 3, day: 31 } }));

      const [saved] = await database.query(
        `select membership_term, membership_year_end_month, membership_year_end_day,
                membership_months
           from temples where id = 'drolma-ling-centre'`,
      );
      expect(saved).toEqual({
        membership_term: 'fixed_year_end',
        membership_year_end_month: 3,
        membership_year_end_day: 31,
        membership_months: null,
      });
    });

    it('never makes a second temple of a request sent twice, and says which exists', async () => {
      await temples.create(drolmaLing());

      await expect(temples.create(drolmaLing({ description: 'Sent again' }))).rejects.toMatchObject(
        {
          kind: 'conflict',
          message: expect.stringContaining('"Drolma Ling Centre" already has the id'),
          details: { reason: 'templeExists' },
        },
      );
      const saved = await database.query(
        `select description from temples where id = 'drolma-ling-centre'`,
      );
      expect(saved).toEqual([{ description: 'Kagyu tradition · Vancouver' }]);
    });

    it('lets two temples share a name under different ids', async () => {
      await temples.create(drolmaLing());

      const second = await temples.create(drolmaLing({ id: 'drolma-ling-calgary' }));

      expect(second.id).toBe('drolma-ling-calgary');
    });

    it('refuses a name the standard card cannot print', async () => {
      await expect(
        temples.create(drolmaLing({ id: 'drolma-ling', name: 'སྒྲོལ་མ་གླིང་།' })),
      ).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { name: expect.any(String) } },
      });
      await expect(
        temples.create(
          drolmaLing({
            name: 'The Jangchub Choling Tibetan Buddhist Meditation and Cultural Centre of Ontario',
          }),
        ),
      ).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { name: expect.any(String) } },
      });
      expect(await database.query(`select id from temples`)).toHaveLength(1);
    });

    it('asks for an id when the name has no letters to make one from', async () => {
      await expect(
        temples.create(drolmaLing({ name: 'སྒྲོལ་མ་གླིང་།', cardTemplate: loseling })),
      ).rejects.toMatchObject({ kind: 'invalid', details: { fields: { id: expect.any(String) } } });
    });

    it('is ready to add members: its own numbers, on a card with its name', async () => {
      const temple = await temples.create(
        drolmaLing({ memberNumber: { next: 500, prefix: 'DL-', minDigits: 4 } }),
      );
      await temples.addAdmin(temple.id, lama.email);
      const members = new MemberService(
        access,
        new PostgresMemberRepository(database),
        files,
        cardRenderer,
        () => new Date('2026-10-01T18:00:00Z'),
      );

      const added = await members.create(lama, {
        id: randomUUID(),
        name: 'Yeshi Lhamo',
        photo: await photo(600, 800),
      });

      if ('taken' in added) throw new Error('The first number cannot be taken.');
      expect(added.member.number).toBe('DL-0500');
      expect((await textOn(added.pdf, 1)).map((run) => run.text)).toEqual([
        'Drolma Ling Centre',
        'Yeshi Lhamo',
        'Valid until 1 October 2027',
        'Membership number',
        'DL-0500',
      ]);
    });
  });

  describe('its logo', () => {
    beforeEach(async () => void (await temples.create(drolmaLing())));

    it('is kept as a PNG no larger than a screen or card needs', async () => {
      const temple = await temples.setLogo('drolma-ling-centre', await photo(1600, 1200));

      expect(temple.logoKey).toMatch(/^temples\/drolma-ling-centre\/logo-[0-9a-f-]{36}\.png$/);
      const stored = files.files.get(temple.logoKey!)!;
      expect(stored.contentType).toBe('image/png');
      expect(await sharp(stored.bytes).metadata()).toMatchObject({
        format: 'png',
        width: 512,
        height: 384,
      });
      const saved = await database.query(
        `select logo_key from temples where id = 'drolma-ling-centre'`,
      );
      expect(saved).toEqual([{ logo_key: temple.logoKey }]);
    });

    it('is not blown up when it is small', async () => {
      const temple = await temples.setLogo('drolma-ling-centre', await photo(120, 120, 'png'));

      const stored = files.files.get(temple.logoKey!)!;
      expect(await sharp(stored.bytes).metadata()).toMatchObject({ width: 120, height: 120 });
    });

    it('is replaced under a new name, so nothing goes on showing the old one', async () => {
      const first = await temples.setLogo('drolma-ling-centre', await photo(64, 64));

      const second = await temples.setLogo('drolma-ling-centre', await photo(64, 64));

      expect(second.logoKey).not.toBe(first.logoKey);
      expect(files.files.size).toBe(2);
    });

    it('must be a picture', async () => {
      await expect(
        temples.setLogo('drolma-ling-centre', Buffer.from('%PDF-1.4 not a picture')),
      ).rejects.toMatchObject({
        kind: 'invalid',
        details: { fields: { logo: expect.any(String) } },
      });
      expect(files.files.size).toBe(0);
    });

    it('needs a temple that exists', async () => {
      await expect(temples.setLogo('no-such-temple', await photo(64, 64))).rejects.toMatchObject({
        kind: 'notFound',
      });
      expect(files.files.size).toBe(0);
    });
  });

  describe('assigning it to its admin', () => {
    beforeEach(async () => void (await temples.create(drolmaLing())));

    it('puts their email on the team as admin and gives it an account', async () => {
      const temple = await temples.addAdmin('drolma-ling-centre', lama.email);

      expect(temple.id).toBe('drolma-ling-centre');
      expect(await team('drolma-ling-centre')).toEqual([{ email: lama.email, role: 'admin' }]);
      expect(accounts.ensured).toEqual([lama.email]);
    });

    it('sent twice, leaves them on the team once', async () => {
      await temples.addAdmin('drolma-ling-centre', lama.email);
      await temples.addAdmin('drolma-ling-centre', lama.email);

      expect(await team('drolma-ling-centre')).toHaveLength(1);
    });

    it('makes an admin of someone already on the team in another role', async () => {
      await addToTeam(database, lama.email, 'volunteer', 'drolma-ling-centre');

      await temples.addAdmin('drolma-ling-centre', lama.email);

      expect(await team('drolma-ling-centre')).toEqual([{ email: lama.email, role: 'admin' }]);
    });

    it('lets one person run several temples', async () => {
      await temples.addAdmin('drolma-ling-centre', lama.email);
      await temples.addAdmin(loseling, lama.email);

      const roles = await access.rolesOf(lama);
      expect(roles.map(({ temple, role }) => [temple.id, role])).toEqual([
        [loseling, 'admin'],
        ['drolma-ling-centre', 'admin'],
      ]);
    });

    it('needs a temple that exists, and makes no account without one', async () => {
      await expect(temples.addAdmin('no-such-temple', lama.email)).rejects.toMatchObject({
        kind: 'notFound',
      });
      expect(accounts.ensured).toEqual([]);
    });
  });

  describe('what its app shows', () => {
    it('starts as members and Add a Member; the first temple has its support letter too', async () => {
      await temples.create(drolmaLing());
      await addToTeam(database, lama.email, 'admin', 'drolma-ling-centre');
      await addToTeam(database, lama.email, 'frontDesk');

      const listed = await temples.templesOf(lama);

      expect(listed.map(({ temple }) => [temple.id, temple.features])).toEqual([
        ['drepung-loseling-canada', ['home.addMember', 'home.letter', 'tab.members']],
        ['drolma-ling-centre', ['home.addMember', 'tab.members']],
      ]);
    });

    it('is replaced as a whole, and is the same however often it is sent', async () => {
      const features = ['tab.offerings', 'home.donate', 'home.receipt'] as const;

      await temples.setFeatures(loseling, [...features]);
      const temple = await temples.setFeatures(loseling, [...features]);

      expect(temple.features).toEqual(['home.donate', 'home.receipt', 'tab.offerings']);
      expect((await repository.find(loseling))?.features).toEqual(temple.features);
    });

    it('can be nothing but Home and More', async () => {
      const temple = await temples.setFeatures(loseling, []);

      expect(temple.features).toEqual([]);
    });

    it('is for one temple only', async () => {
      await temples.create(drolmaLing());

      await temples.setFeatures('drolma-ling-centre', ['tab.calendar']);

      expect((await repository.find(loseling))?.features).toEqual([
        'home.addMember',
        'home.letter',
        'tab.members',
      ]);
    });

    it('needs a temple that exists', async () => {
      await expect(temples.setFeatures('no-such-temple', ['tab.members'])).rejects.toMatchObject({
        kind: 'notFound',
      });
    });
  });

  describe('the temples someone works at', () => {
    it('are theirs alone, each with its role and logo', async () => {
      await temples.create(drolmaLing());
      const withLogo = await temples.setLogo('drolma-ling-centre', await photo(64, 64));
      await temples.addAdmin('drolma-ling-centre', lama.email);

      const listed = await temples.templesOf(lama);

      expect(listed).toEqual([
        { temple: withLogo, role: 'admin', logo: files.files.get(withLogo.logoKey!)!.bytes },
      ]);
    });

    it('have no logo until one is uploaded', async () => {
      await addToTeam(database, lama.email, 'frontDesk');

      const [listed] = await temples.templesOf(lama);

      expect(listed).toMatchObject({
        temple: { id: loseling },
        role: 'frontDesk',
        logo: undefined,
      });
    });

    it('are still listed, without the logo, when a logo cannot be read', async () => {
      await temples.create(drolmaLing());
      await temples.setLogo('drolma-ling-centre', await photo(64, 64));
      await temples.addAdmin('drolma-ling-centre', lama.email);
      files.files.clear();

      const [listed] = await temples.templesOf(lama);

      expect(listed).toMatchObject({ temple: { id: 'drolma-ling-centre' }, logo: undefined });
    });

    it('turn away someone no temple was assigned to', async () => {
      await temples.create(drolmaLing());

      await expect(temples.templesOf(lama)).rejects.toMatchObject({
        kind: 'permissionDenied',
        details: { reason: 'notOnTeam' },
      });
    });
  });
});

describe('idFromName', () => {
  it.each([
    ['Drepung Loseling Canada', 'drepung-loseling-canada'],
    ['  Drolma Ling — Centre  ', 'drolma-ling-centre'],
    ['Thrangu Monastery (B.C.)', 'thrangu-monastery-b-c'],
    ['Centre Bouddhiste Kagyü-Dzong', 'centre-bouddhiste-kagyu-dzong'],
    ['སྒྲོལ་མ་གླིང་།', ''],
  ])('%s → %s', (name, id) => {
    expect(idFromName(name)).toBe(id);
  });

  it('stays within sixty characters, without ending on a hyphen', () => {
    const id = idFromName(`${'Jangchub '.repeat(6)}Choling Centre`);

    expect(id.length).toBeLessThanOrEqual(60);
    expect(id).toMatch(/^[a-z0-9]+(-[a-z0-9]+)*$/);
  });
});

describe('what the temple functions accept', () => {
  /** The fields a request is refused for, by `schema`. */
  const refusedBy = (schema: Parameters<typeof parseInput>[0], data: unknown) => {
    try {
      parseInput(schema, data);
    } catch (error) {
      return Object.keys((error as { details: { fields: object } }).details.fields);
    }
    return [];
  };

  it('needs only a name and a time zone, and fills in the rest', () => {
    const temple = parseInput(newTempleInput, {
      name: '  Drolma Ling Centre ',
      timeZone: 'America/Vancouver',
    });

    expect(temple).toEqual({
      name: 'Drolma Ling Centre',
      description: '',
      timeZone: 'America/Vancouver',
      cardTemplate: 'standard',
      membership: { kind: 'rolling', months: 12 },
      memberNumber: { next: 1, prefix: '', minDigits: 0 },
    });
  });

  it('takes a temple’s own choices', () => {
    const sent = {
      id: 'drolma-ling',
      name: 'Drolma Ling Centre',
      description: 'Kagyu tradition · Vancouver',
      timeZone: 'America/Vancouver',
      cardTemplate: 'drepung-loseling-canada',
      membership: { kind: 'fixedYearEnd', month: 7, day: 31 },
      memberNumber: { next: 142, prefix: 'DL-', minDigits: 4 },
    };

    expect(parseInput(newTempleInput, sent)).toEqual(sent);
    expect(
      parseInput(newTempleInput, { ...sent, memberNumber: { prefix: 'DL-' } }).memberNumber,
    ).toEqual({ next: 1, prefix: 'DL-', minDigits: 0 });
  });

  it('refuses what it cannot use, field by field', () => {
    const sent = { name: 'Drolma Ling Centre', timeZone: 'America/Vancouver' };
    const refused = (changes: Record<string, unknown>) =>
      refusedBy(newTempleInput, { ...sent, ...changes });

    expect(refused({ name: ' ' })).toEqual(['name']);
    expect(refused({ timeZone: 'Vancouver' })).toEqual(['timeZone']);
    expect(refused({ timeZone: undefined })).toEqual(['timeZone']);
    expect(refused({ id: 'Drolma Ling' })).toEqual(['id']);
    expect(refused({ cardTemplate: 'gold-foil' })).toEqual(['cardTemplate']);
    expect(refused({ membership: { kind: 'rolling', months: 0 } })).toEqual(['membership.months']);
    expect(refused({ membership: { kind: 'forever' } })).toEqual(['membership.kind']);
    expect(refused({ memberNumber: { next: 0 } })).toEqual(['memberNumber.next']);
    expect(refused({ description: 'x'.repeat(201) })).toEqual(['description']);
  });

  it('says what is wrong in words the operator can act on', () => {
    const said = (changes: Record<string, unknown>) => {
      try {
        parseInput(newTempleInput, {
          name: 'Drolma Ling Centre',
          timeZone: 'America/Vancouver',
          ...changes,
        });
      } catch (error) {
        return Object.values((error as { details: { fields: object } }).details.fields);
      }
      return [];
    };

    expect(said({ membership: { kind: 'rolling', months: 121 } })).toEqual([
      'A whole number of months, 1 to 120.',
    ]);
    expect(said({ memberNumber: { minDigits: -1 } })).toEqual(['A whole number, 0 to 12.']);
    expect(said({ memberNumber: { next: 0 } })).toEqual(['A whole number, 1 or more.']);
    expect(said({ memberNumber: { prefix: 'JC\u0000' } })).toEqual(['Typed letters only.']);
    expect(said({ memberNumber: { prefix: 'x'.repeat(11) } })).toEqual(['At most 10 characters.']);
  });

  it('takes a logo as the bytes of an image, up to 5 MB', () => {
    const logo = Buffer.from([0x89, 0x50, 0x4e, 0x47]);

    expect(parseInput(templeLogoInput, { templeId: 'drolma-ling', logo })).toEqual({
      templeId: 'drolma-ling',
      logo,
    });
    expect(refusedBy(templeLogoInput, { templeId: 'drolma-ling', logo: Buffer.alloc(0) })).toEqual([
      'logo',
    ]);
    const tooLarge = Buffer.alloc(5 * 1024 * 1024 + 1);
    expect(refusedBy(templeLogoInput, { templeId: 'drolma-ling', logo: tooLarge })).toEqual([
      'logo',
    ]);
    expect(refusedBy(templeLogoInput, { logo: tooLarge })).toEqual(['templeId', 'logo']);
    expect(refusedBy(templeLogoInput, { templeId: 'drolma-ling', logo: 'iVBORw0KGgo=' })).toEqual([
      'logo',
    ]);
  });

  it('takes what the app shows by name, each once, and says which names there are', () => {
    expect(
      parseInput(templeFeaturesInput, {
        templeId: 'drolma-ling',
        features: ['tab.members', 'home.letter', 'tab.members'],
      }),
    ).toEqual({ templeId: 'drolma-ling', features: ['tab.members', 'home.letter'] });
    expect(parseInput(templeFeaturesInput, { templeId: 'drolma-ling', features: [] })).toEqual({
      templeId: 'drolma-ling',
      features: [],
    });

    expect(refusedBy(templeFeaturesInput, { templeId: 'drolma-ling' })).toEqual(['features']);
    expect(
      refusedBy(templeFeaturesInput, { templeId: 'drolma-ling', features: 'tab.members' }),
    ).toEqual(['features']);
    try {
      parseInput(templeFeaturesInput, { templeId: 'drolma-ling', features: ['tab.home'] });
      expect.unreachable();
    } catch (error) {
      const fields = (error as { details: { fields: Record<string, string> } }).details.fields;
      expect(Object.keys(fields)).toEqual(['features.0']);
      expect(fields['features.0']).toMatch(
        /^One of: tab\.members, tab\.offerings, .*home\.myCard\.$/,
      );
    }
  });

  it('takes an admin’s email however it is capitalised, but not half an address', () => {
    expect(
      parseInput(templeAdminInput, {
        templeId: 'drolma-ling',
        email: ' Lama.Karma@DrolmaLing.ca ',
      }),
    ).toEqual({ templeId: 'drolma-ling', email: 'lama.karma@drolmaling.ca' });
    expect(refusedBy(templeAdminInput, { templeId: 'drolma-ling', email: 'lama.karma@' })).toEqual([
      'email',
    ]);
    expect(refusedBy(templeAdminInput, {})).toEqual(['templeId', 'email']);
  });
});
