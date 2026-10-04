import type { CallableOptions } from 'firebase-functions/v2/https';

import { parseIsoDate, toIsoDate } from '../../core/calendar-date';
import { defineCallable } from '../../core/callable';
import { lazy } from '../../core/lazy';
import { database, fileStore } from '../../runtime';
import { templeAccess } from '../temples';
import type { Letter } from './letter';
import { letterRenderer } from './letter-templates';
import { letterInput, listLettersInput, newLetterInput, previewLetterInput } from './letters.input';
import { LetterService } from './letters.service';
import { PostgresLetterRepository } from './postgres-letter.repository';

const service = lazy(
  async () =>
    new LetterService(
      await templeAccess(),
      new PostgresLetterRepository(await database()),
      await fileStore(),
      letterRenderer,
      () => new Date(),
    ),
);

// Drawing a letter needs room for the letterhead, the fonts and the PDF.
const drawsLetters: CallableOptions = { memory: '1GiB', timeoutSeconds: 60 };

const base64 = (pdf: Uint8Array) => Buffer.from(pdf).toString('base64');

/** A letter as the app lists it. */
const letterJson = (letter: Letter) => ({
  id: letter.id,
  number: letter.number,
  name: letter.name,
  memberId: letter.memberId,
  validUntil: toIsoDate(letter.validUntil),
  issuedOn: toIsoDate(letter.issuedOn),
});

/** `letters-list`: the temple's letters, the newest first. */
export const list = defineCallable({
  input: listLettersInput,
  handler: async (caller, input) => {
    const letters = await service();
    return { letters: (await letters.list(caller, input?.templeId)).map(letterJson) };
  },
});

/** `letters-get`: a letter on file, with what it says and its page. */
export const get = defineCallable({
  input: letterInput,
  handler: async (caller, input) => {
    const letters = await service();
    const { letter, body, pdf } = await letters.get(caller, input);
    return { letter: letterJson(letter), body, file: { pdf: base64(pdf) } };
  },
});

/** `letters-preview`: the letter a request would issue. Nothing is saved. */
export const preview = defineCallable({
  options: drawsLetters,
  input: previewLetterInput,
  handler: async (caller, input) => {
    const letters = await service();
    const result = await letters.preview(caller, {
      ...input,
      validUntil: parseIsoDate(input.validUntil),
    });
    return 'tooLong' in result
      ? { tooLong: result.tooLong }
      : { number: result.number, spare: result.spare, file: { pdf: base64(result.pdf) } };
  },
});

/**
 * `letters-create`: issues a letter and returns it with its page. If the
 * number typed belongs to another letter, says which and issues nothing.
 */
export const create = defineCallable({
  options: drawsLetters,
  input: newLetterInput,
  handler: async (caller, input) => {
    const letters = await service();
    const result = await letters.create(caller, {
      ...input,
      validUntil: parseIsoDate(input.validUntil),
    });
    return 'taken' in result
      ? { taken: { name: result.taken.name, number: result.taken.number } }
      : { letter: letterJson(result.letter), file: { pdf: base64(result.pdf) } };
  },
});
