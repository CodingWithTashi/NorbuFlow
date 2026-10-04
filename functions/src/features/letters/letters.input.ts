import { z } from 'zod';

import { noControlChars } from '../../core/validation';
import type { LetterBody } from './letter';

// Far more than a page holds: whether a body fits is the service's question.
const maxLines = 200;
const maxCharacters = 10_000;

// Ids are chosen by the app. A bad one is its bug, so it has no issue name.
const uuid = z.uuid();

// Who the letter is for. Kept with it to find it by; it is not printed.
const name = z
  .string('letterNameRequired')
  .trim()
  .regex(noControlChars, 'letterNameRequired')
  .min(1, 'letterNameRequired')
  .max(120, 'letterNameTooLong');

// Picked from a calendar in the app, so a bad one is its bug.
const validUntil = z.iso.date().refine((date) => date >= '2000-01-01' && date <= '2100-12-31');

const mark = z.boolean('letterBodyRequired').optional();

const run = z.object(
  {
    text: z
      .string('letterBodyRequired')
      .max(maxCharacters, 'letterBodyTooLong')
      .regex(noControlChars, 'letterBodyUnsupported'),
    bold: mark,
    italic: mark,
    underline: mark,
  },
  'letterBodyRequired',
);

const line = z.object(
  { bullet: mark, runs: z.array(run, 'letterBodyRequired').max(maxLines, 'letterBodyTooLong') },
  'letterBodyRequired',
);

const lines = z.array(line, 'letterBodyRequired').max(maxLines, 'letterBodyTooLong');

// Soft hyphens, zero-width spaces and direction marks: a font sets them as a gap.
const unseen = /[\u00AD\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]/g;

// Drops what prints nothing. Empty lines before the first words stay: they
// are how far down the page the letter starts.
function tidy(body: LetterBody): LetterBody {
  const tidied = body.map(({ bullet, runs }) => {
    // An accent sent as a mark of its own joins its letter, which the font has.
    const kept = runs
      .map((each) => ({ ...each, text: each.text.normalize('NFC').replace(unseen, '') }))
      .filter((each) => each.text !== '');
    // Spaces at the line's two ends go, with any run that was nothing else.
    while (kept.length > 0 && (kept[0]!.text = kept[0]!.text.trimStart()) === '') kept.shift();
    while (kept.length > 0 && (kept.at(-1)!.text = kept.at(-1)!.text.trimEnd()) === '') kept.pop();
    return { ...(bullet && kept.length > 0 ? { bullet } : {}), runs: kept };
  });
  const written = (each: { runs: unknown[] }) => each.runs.length > 0;
  return tidied.slice(0, tidied.findLastIndex(written) + 1);
}

// Whatever is wrong inside the body is reported against the body: it is one
// field in the app.
const body = z.unknown().transform((value, context): LetterBody => {
  const parsed = lines.safeParse(value);
  const issue = (message: string) => {
    context.addIssue({ code: 'custom', message });
    return z.NEVER;
  };
  if (!parsed.success) return issue(parsed.error.issues[0]!.message);

  const tidied = tidy(parsed.data);
  const characters = tidied.reduce(
    (total, each) => each.runs.reduce((sum, { text }) => sum + text.length, total),
    0,
  );
  if (characters === 0) return issue('letterBodyRequired');
  if (characters > maxCharacters) return issue('letterBodyTooLong');
  return tidied;
});

// A letter number typed by hand: digits, above zero. Zeros in front do not count.
const number = z
  .string('letterNumberInvalid')
  .trim()
  .max(30, 'letterNumberInvalid')
  .regex(/^0*[1-9][0-9]{0,14}$/, 'letterNumberInvalid')
  .transform((digits) => digits.replace(/^0+/, ''))
  .optional();

const templeId = z
  .string('templeRequired')
  .min(1, 'templeRequired')
  .max(60, 'templeRequired')
  .optional();

const letter = {
  name,
  // The member it is for. Left out, it is for someone who is not one.
  memberId: uuid.optional(),
  validUntil,
  body,
  // Left out, the letter gets the temple's next number.
  number,
  templeId,
};

/** What `letters-preview` takes: a letter to draw. Nothing is saved. */
export const previewLetterInput = z.object(letter);

/**
 * What `letters-create` takes: each value present, tidied and within its
 * limits. Whether the page can hold the body is the service's question.
 */
export const newLetterInput = z.object({
  // Names the letter this request issues: sent again, it returns the same one.
  id: uuid,
  ...letter,
});

// The app sends nothing at all when the caller works at one temple.
export const listLettersInput = z.object({ templeId }).nullish();

export const letterInput = z.object({ letterId: uuid, templeId });
