import { randomUUID } from 'node:crypto';

import { beforeEach, describe, expect, it } from 'vitest';

import type { Database } from '../../../src/core/database';
import { type FileStore, InMemoryFileStore } from '../../../src/core/file-store';
import { parseInput } from '../../../src/core/validation';
import { letterRenderer } from '../../../src/features/letters/letter-templates';
import { newLetterInput, previewLetterInput } from '../../../src/features/letters/letters.input';
import {
  LetterService,
  type NewLetterRequest,
} from '../../../src/features/letters/letters.service';
import { PostgresLetterRepository } from '../../../src/features/letters/postgres-letter.repository';
import { PostgresTempleRepository } from '../../../src/features/temples/postgres-temple.repository';
import { TempleAccess } from '../../../src/features/temples/temple-access';
import { addToTeam, freshDatabase, loseling } from '../../support/database';
import { paragraphs, sampleBody } from '../../support/letters';
import { pageCount, textOn } from '../../support/pdf';

const dolma = { uid: 'uid-dolma', email: 'dolma@example.org' };

// Each letter is drawn on the letterhead with its fonts whole, which takes a moment.
describe('support letters', { timeout: 30_000 }, () => {
  let database: Database;
  let files: InMemoryFileStore;
  // Thursday 1 October 2026, mid-morning in Toronto.
  let now = new Date('2026-10-01T14:30:00Z');

  const service = (store: FileStore = files) =>
    new LetterService(
      new TempleAccess(new PostgresTempleRepository(database)),
      new PostgresLetterRepository(database),
      store,
      letterRenderer,
      () => now,
    );

  const forKunsel = (changes: Partial<NewLetterRequest> = {}): NewLetterRequest => ({
    id: randomUUID(),
    name: 'Tenzin Kunsel',
    validUntil: { year: 2027, month: 10, day: 1 },
    body: sampleBody,
    ...changes,
  });

  /** Issues a letter, which must not be turned away for its number. */
  const issue = async (request: NewLetterRequest = forKunsel(), store: FileStore = files) => {
    const result = await service(store).create(dolma, request);
    if ('taken' in result) throw new Error(`The letter for ${result.taken.name} has that number.`);
    return result;
  };

  const printed = async (pdf: Uint8Array) => (await textOn(pdf, 1)).map((run) => run.text);

  // A temple with no letterhead of its own.
  const addJangchub = () =>
    database.query(
      `insert into temples
         (id, name, time_zone, card_template, membership_term, membership_months)
       values ('jangchub', 'Jangchub Choling', 'America/Vancouver', 'standard', 'rolling', 12)`,
    );

  beforeEach(async () => {
    database = await freshDatabase();
    files = new InMemoryFileStore();
    now = new Date('2026-10-01T14:30:00Z');
    await addToTeam(database, dolma.email, 'admin');
    return async () => database.close();
  });

  describe('issuing one', () => {
    it('numbers it after the temple’s hand-made letters and files its page', async () => {
      const request = forKunsel();

      const { letter, pdf } = await issue(request);

      expect(letter).toEqual({
        id: request.id,
        templeId: loseling,
        number: '195960',
        name: 'Tenzin Kunsel',
        memberId: null,
        validUntil: { year: 2027, month: 10, day: 1 },
        // The day in Toronto, where the temple is.
        issuedOn: { year: 2026, month: 10, day: 1 },
      });
      expect(await pageCount(pdf)).toBe(1);
      const text = await printed(pdf);
      expect(text).toContain('No. 195960');
      expect(text).toContain('Valid Until Oct 1, 2027');
      expect(text).toContain('member of our team.');
      const key = `temples/${loseling}/letters/${request.id}.pdf`;
      expect([...files.files.keys()]).toEqual([key]);
      expect(await files.get(key)).toEqual(pdf);
    });

    it('gives each letter the next number', async () => {
      const first = await issue();
      const second = await issue();

      expect([first.letter.number, second.letter.number]).toEqual(['195960', '195961']);
    });

    it('dates it by the temple’s day, not the server’s', async () => {
      // Half past eleven at night in Toronto is already tomorrow in UTC.
      now = new Date('2026-10-02T03:30:00Z');

      const { letter } = await issue(forKunsel({ validUntil: { year: 2026, month: 10, day: 1 } }));

      expect(letter.issuedOn).toEqual({ year: 2026, month: 10, day: 1 });
    });

    it('issues one letter, however often the request is sent', async () => {
      const request = forKunsel();

      const first = await issue(request);
      const again = await issue(request);
      const next = await issue();

      expect(again.letter).toEqual(first.letter);
      expect(again.pdf).toEqual(first.pdf);
      expect(next.letter.number).toBe('195961');
      expect(await service().list(dolma)).toHaveLength(2);
    });

    it('issues one letter when the same request arrives twice at once', async () => {
      const request = forKunsel();

      const [first, second] = await Promise.all([issue(request), issue(request)]);

      expect(second.letter).toEqual(first.letter);
      expect(await service().list(dolma)).toHaveLength(1);
    });

    it('keeps a link to the member it is for', async () => {
      const [member] = await database.query<{ id: string }>(
        `insert into members
           (temple_id, number, name, photo_key, joined_on, renewed_on, expires_on, created_by)
         values ($1, 194915306, 'Tenzin Kunsel', 'photo', '2025-08-01', '2026-08-01',
                 '2027-07-31', 'uid-dolma')
         returning id`,
        [loseling],
      );

      const memberId = member!.id;

      const { letter } = await issue(forKunsel({ memberId }));

      expect(letter.memberId).toBe(memberId);
      expect((await service().list(dolma))[0]?.memberId).toBe(memberId);
    });

    it('is returned again even once its last day has passed', async () => {
      const request = forKunsel({ validUntil: { year: 2026, month: 10, day: 1 } });
      const first = await issue(request);
      // The answer was lost; the app asks again after midnight in Toronto.
      now = new Date('2026-10-02T14:30:00Z');

      const again = await issue(request);

      expect(again.letter).toEqual(first.letter);
      expect(await service().list(dolma)).toHaveLength(1);
    });

    it('is for a member of this temple, or for nobody on file', async () => {
      const stranger = randomUUID();

      await expect(
        service().preview(dolma, forKunsel({ memberId: stranger })),
      ).rejects.toMatchObject({
        kind: 'notFound',
      });
      await expect(
        service().create(dolma, forKunsel({ memberId: stranger })),
      ).rejects.toMatchObject({
        kind: 'notFound',
      });
      // Refused before anything was drawn, filed or numbered.
      expect(files.files.size).toBe(0);
      expect((await issue()).letter.number).toBe('195960');
    });

    it('takes nothing when its page cannot be stored', async () => {
      const failing: FileStore = {
        put: () => Promise.reject(new Error('The bucket is down.')),
        get: (key) => files.get(key),
        urlFor: () => Promise.resolve(null),
      };

      await expect(issue(forKunsel(), failing)).rejects.toThrow('The bucket is down.');

      expect(await service().list(dolma)).toEqual([]);
      expect((await issue()).letter.number).toBe('195960');
    });
  });

  describe('a number typed by hand', () => {
    it('is used as it is, and skipped when the count reaches it', async () => {
      const typed = await issue(forKunsel({ number: '195961' }));
      const first = await issue();
      const second = await issue();

      expect(typed.letter.number).toBe('195961');
      expect(await printed(typed.pdf)).toContain('No. 195961');
      expect([first.letter.number, second.letter.number]).toEqual(['195960', '195962']);
    });

    it('may be one of the letters made before the app', async () => {
      const { letter } = await issue(forKunsel({ number: '195956' }));

      expect(letter.number).toBe('195956');
      expect((await issue()).letter.number).toBe('195960');
    });

    it('that another letter carries issues nothing and says whose it is', async () => {
      const first = await issue(forKunsel({ name: 'Pema Lhamo' }));

      const result = await service().create(dolma, forKunsel({ number: first.letter.number }));

      expect(result).toEqual({ taken: first.letter });
      expect(await service().list(dolma)).toHaveLength(1);
      expect(files.files.size).toBe(1);
    });
  });

  describe('a preview', () => {
    it('draws the letter with the number it would get, and saves nothing', async () => {
      const preview = await service().preview(dolma, forKunsel());

      if ('tooLong' in preview) throw new Error('The letter fits.');
      expect(preview.number).toBe('195960');
      expect(await printed(preview.pdf)).toContain('No. 195960');
      expect(await service().list(dolma)).toEqual([]);
      expect(files.files.size).toBe(0);
      // The number was not taken: the next letter still gets it.
      expect((await issue()).letter.number).toBe('195960');
    });

    it('says how many lines of room are left under the body', async () => {
      const short = await service().preview(dolma, forKunsel({ body: paragraphs('One line.') }));
      const sample = await service().preview(dolma, forKunsel());

      expect(short).toMatchObject({ spare: 24 });
      // The temple’s own letter takes 23 of the 25 lines.
      expect(sample).toMatchObject({ spare: 2 });
    });

    it('starts the body lower by each empty line before it, down to the last line of room', async () => {
      const words = paragraphs('A short letter.');
      const down = (lines: number) => [...Array(lines).fill({ runs: [] }), ...words];
      const firstLine = async (body: typeof words) => {
        const preview = await service().preview(dolma, forKunsel({ body }));
        if ('tooLong' in preview) throw new Error('The letter fits.');
        const line = (await textOn(preview.pdf, 1)).find((run) => run.text === 'A short letter.')!;
        return { y: line.y, spare: preview.spare };
      };

      const top = await firstLine(words);
      const lower = await firstLine(down(10));
      const lowest = await firstLine(down(24));

      expect(top).toMatchObject({ y: 646.22, spare: 24 });
      expect(lower.y).toBeCloseTo(646.2202 - 10 * 17.0038, 3);
      expect(lower.spare).toBe(14);
      expect(lowest.spare).toBe(0);
      // One more and it would run into "Sincerely,".
      expect(await service().preview(dolma, forKunsel({ body: down(25) }))).toEqual({
        tooLong: { lines: 1 },
      });
    });

    it('carries a number typed by hand', async () => {
      const preview = await service().preview(dolma, forKunsel({ number: '777' }));

      expect(preview).toMatchObject({ number: '777' });
    });

    it('is the letter that issuing the same request makes', async () => {
      const request = forKunsel();

      const preview = await service().preview(dolma, request);
      const { pdf } = await issue(request);

      if ('tooLong' in preview) throw new Error('The letter fits.');
      expect(await textOn(pdf, 1)).toEqual(await textOn(preview.pdf, 1));
    });

    it('says how many lines too long a body is instead of drawing it', async () => {
      const body = [...sampleBody, { runs: [] }, ...paragraphs('One more line.', 'And another.')];

      expect(await service().preview(dolma, forKunsel({ body }))).toEqual({
        tooLong: { lines: 2 },
      });
    });
  });

  describe('what it refuses', () => {
    const fields = (request: Promise<unknown>) =>
      request.then(
        () => undefined,
        (error: { details?: { fields?: unknown } }) => error.details?.fields,
      );

    it('a body too long for the page, with no number taken', async () => {
      const body = [...sampleBody, { runs: [] }, ...sampleBody];

      expect(await fields(service().create(dolma, forKunsel({ body })))).toEqual({
        body: 'letterBodyTooLong',
      });
      expect((await issue()).letter.number).toBe('195960');
    });

    it('letters the letterhead’s font does not have', async () => {
      const body = paragraphs('བཀྲ་ཤིས་བདེ་ལེགས།');

      expect(await fields(service().preview(dolma, forKunsel({ body })))).toEqual({
        body: 'letterBodyUnsupported',
      });
      expect(await fields(service().create(dolma, forKunsel({ body })))).toEqual({
        body: 'letterBodyUnsupported',
      });
    });

    it('a last day that has passed, by the temple’s calendar', async () => {
      const yesterday = { year: 2026, month: 9, day: 30 };
      const today = { year: 2026, month: 10, day: 1 };

      expect(await fields(service().preview(dolma, forKunsel({ validUntil: yesterday })))).toEqual({
        validUntil: 'letterDatePast',
      });
      expect(await fields(service().create(dolma, forKunsel({ validUntil: yesterday })))).toEqual({
        validUntil: 'letterDatePast',
      });
      expect((await issue(forKunsel({ validUntil: today }))).letter.validUntil).toEqual(today);
    });

    it('a temple with no letterhead', async () => {
      await addJangchub();
      await addToTeam(database, 'pema@example.org', 'admin', 'jangchub');
      const pema = { uid: 'uid-pema', email: 'pema@example.org' };

      await expect(service().preview(pema, forKunsel())).rejects.toMatchObject({
        kind: 'notFound',
      });
      await expect(service().create(pema, forKunsel())).rejects.toMatchObject({ kind: 'notFound' });
    });
  });

  describe('who may', () => {
    it('is the temple’s admins only', async () => {
      const { letter } = await issue();
      for (const role of [
        'geshe',
        'accountant',
        'frontDesk',
        'coordinator',
        'volunteer',
        'member',
      ]) {
        const person = { uid: `uid-${role}`, email: `${role.toLowerCase()}@example.org` };
        await addToTeam(database, person.email, role);

        await expect(service().preview(person, forKunsel())).rejects.toMatchObject({
          kind: 'permissionDenied',
        });
        await expect(service().create(person, forKunsel())).rejects.toMatchObject({
          kind: 'permissionDenied',
        });
        await expect(service().list(person)).rejects.toMatchObject({ kind: 'permissionDenied' });
        await expect(service().get(person, { letterId: letter.id })).rejects.toMatchObject({
          kind: 'permissionDenied',
        });
      }
      expect(await service().list(dolma)).toHaveLength(1);
    });

    it('is nobody from another temple', async () => {
      await addJangchub();
      await addToTeam(database, 'pema@example.org', 'admin', 'jangchub');
      const pema = { uid: 'uid-pema', email: 'pema@example.org' };
      const { letter } = await issue();

      expect(await service().list(pema)).toEqual([]);
      await expect(service().get(pema, { letterId: letter.id })).rejects.toMatchObject({
        kind: 'notFound',
      });
      await expect(
        service().get(pema, { letterId: letter.id, templeId: loseling }),
      ).rejects.toMatchObject({ kind: 'permissionDenied' });
    });
  });

  describe('letters on file', () => {
    it('are listed newest first', async () => {
      await issue(forKunsel({ name: 'Pema Lhamo' }));
      await issue(forKunsel({ name: 'Karma Dhondup' }));

      const listed = await service().list(dolma);

      expect(listed.map((letter) => [letter.name, letter.number])).toEqual([
        ['Karma Dhondup', '195961'],
        ['Pema Lhamo', '195960'],
      ]);
    });

    it('come back with what they say and the page that was filed', async () => {
      const body = [
        // Moved two lines down the page.
        { runs: [] },
        { runs: [] },
        {
          runs: [
            { text: 'She has been a ' },
            { text: 'dedicated', bold: true },
            { text: ' member.' },
          ],
        },
        { runs: [] },
        { bullet: true, runs: [{ text: 'Cooking', italic: true }] },
      ];
      const issued = await issue(forKunsel({ body }));

      const onFile = await service().get(dolma, { letterId: issued.letter.id });

      expect(onFile.letter).toEqual(issued.letter);
      expect(onFile.body).toEqual(body);
      expect(onFile.pdf).toEqual(issued.pdf);
    });

    it('are not found by an id no letter has', async () => {
      await expect(service().get(dolma, { letterId: randomUUID() })).rejects.toMatchObject({
        kind: 'notFound',
      });
    });
  });

  describe('what a request must be', () => {
    const request = {
      id: randomUUID(),
      name: '  Tenzin Kunsel ',
      validUntil: '2027-10-01',
      body: [{ runs: [{ text: 'She is a member.' }] }],
    };
    const refused = (changes: object, schema: typeof newLetterInput = newLetterInput) => {
      try {
        parseInput(schema, { ...request, ...changes });
      } catch (error) {
        return (error as { details: { fields: Record<string, string> } }).details.fields;
      }
      return undefined;
    };

    it('is tidied: the name trimmed, the number without the zeros in front', () => {
      expect(parseInput(newLetterInput, { ...request, number: ' 00195960 ' })).toEqual({
        ...request,
        name: 'Tenzin Kunsel',
        number: '195960',
      });
    });

    it('loses what prints nothing: empty runs, spaces at a line’s ends, empty lines at the end', () => {
      const body = [
        { runs: [{ text: '  She is ' }, { text: '' }, { text: 'kind.  ', bold: true }] },
        { runs: [{ text: '   ' }] },
        { bullet: true, runs: [{ text: 'Cooking' }] },
        { bullet: true, runs: [] },
      ];

      expect(parseInput(newLetterInput, { ...request, body }).body).toEqual([
        { runs: [{ text: 'She is ' }, { text: 'kind.', bold: true }] },
        { runs: [] },
        { bullet: true, runs: [{ text: 'Cooking' }] },
      ]);
    });

    it('keeps the empty lines before the first words: they set where the letter starts', () => {
      const body = [{ runs: [] }, { runs: [{ text: '  ' }] }, { runs: [{ text: 'She is kind.' }] }];

      expect(parseInput(newLetterInput, { ...request, body }).body).toEqual([
        { runs: [] },
        { runs: [] },
        { runs: [{ text: 'She is kind.' }] },
      ]);
    });

    it('names who it is for', () => {
      expect(refused({ name: '   ' })).toEqual({ name: 'letterNameRequired' });
      expect(refused({ name: undefined })).toEqual({ name: 'letterNameRequired' });
      expect(refused({ name: 'T'.repeat(121) })).toEqual({ name: 'letterNameTooLong' });
    });

    it('joins an accent to its letter and drops what takes no room', () => {
      const body = [
        { runs: [{ text: 'Jose\u0301 acknowl\u00ADedges it\u200B.' }] },
        { runs: [{ text: '\uFEFF' }] },
        { runs: [{ text: 'Thank you.' }] },
      ];

      expect(parseInput(newLetterInput, { ...request, body }).body).toEqual([
        { runs: [{ text: 'Jos\u00E9 acknowledges it.' }] },
        { runs: [] },
        { runs: [{ text: 'Thank you.' }] },
      ]);
    });

    it('takes a line of spaces alone for an empty line, however it is cut into runs', () => {
      const spaces = { runs: [{ text: ' ' }, { text: ' ', bold: true }, { text: ' ' }] };

      expect(refused({ body: [spaces] })).toEqual({ body: 'letterBodyRequired' });
      expect(
        parseInput(newLetterInput, { ...request, body: [...request.body, spaces, ...request.body] })
          .body[1],
      ).toEqual({ runs: [] });
    });

    it('holds until a day the calendar has', () => {
      expect(refused({ validUntil: '0000-01-01' })).toHaveProperty('validUntil');
      expect(refused({ validUntil: '9999-12-31' })).toHaveProperty('validUntil');
      expect(refused({ validUntil: '2027-02-30' })).toHaveProperty('validUntil');
    });

    it('says something', () => {
      expect(refused({ body: [] })).toEqual({ body: 'letterBodyRequired' });
      expect(refused({ body: undefined })).toEqual({ body: 'letterBodyRequired' });
      expect(refused({ body: [{ runs: [{ text: '   ' }] }] })).toEqual({
        body: 'letterBodyRequired',
      });
    });

    it('reports whatever is wrong inside the body against the body', () => {
      const line = (text: string) => ({ runs: [{ text }] });

      expect(refused({ body: [line('Two\nlines')] })).toEqual({ body: 'letterBodyUnsupported' });
      expect(refused({ body: Array(201).fill(line('A line.')) })).toEqual({
        body: 'letterBodyTooLong',
      });
      expect(refused({ body: Array(11).fill(line('a'.repeat(1000))) })).toEqual({
        body: 'letterBodyTooLong',
      });
      expect(refused({ body: [{ runs: [{ text: 7 }] }] })).toEqual({ body: 'letterBodyRequired' });
    });

    it('has a number of digits above zero, if it has one', () => {
      for (const number of ['0', 'A12', '12.5', '-3', '1'.repeat(16)]) {
        expect(refused({ number }), number).toEqual({ number: 'letterNumberInvalid' });
      }
    });

    it('asks the same of a preview, which needs no id', () => {
      const preview = parseInput(previewLetterInput, request);

      expect(preview).toMatchObject({ name: 'Tenzin Kunsel' });
      expect(preview).not.toHaveProperty('id');
      expect(refused({ name: '' }, previewLetterInput as never)).toEqual({
        name: 'letterNameRequired',
      });
    });
  });
});
