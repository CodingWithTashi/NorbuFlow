import { beforeAll, describe, expect, it } from 'vitest';

import type { LetterBody } from '../../../src/features/letters/letter';
import type { LetterRenderer } from '../../../src/features/letters/letter-renderer';
import { letterRenderer } from '../../../src/features/letters/letter-templates';
import { paragraphs, sampleBody, sampleLines } from '../../support/letters';
import { colourAt, pageCount, pageSize, type PlacedText, textOn } from '../../support/pdf';

/** Whether two colours are the same, give or take how a page is drawn. */
const near = (colour: readonly number[], other: readonly number[]) =>
  colour.every((value, index) => Math.abs(value - other[index]!) < 6);

/** A page's text with the doubled spaces a reader of the PDF may or may not keep made single. */
const plain = (text: string) => text.replace(/\s+/g, ' ').trim();

// The positions asserted here are the ones in the letter the temple made by
// hand. If one changes, the printed letter no longer matches its design.
describe('the Drepung Loseling Canada support letter', () => {
  let renderer: LetterRenderer;
  const validUntil = { year: 2027, month: 7, day: 16 };
  const bodyLeft = 49.795;
  const bodyRight = 49.7949 + 493.2;

  beforeAll(async () => {
    renderer = await letterRenderer('drepung-loseling-canada');
  });

  const letter = (body: LetterBody, number = '195956') =>
    renderer.render({ number, validUntil, body });

  /** The runs of text the letter adds to its letterhead's own. */
  const added = async (pdf: Uint8Array): Promise<PlacedText[]> => {
    const letterhead = await textOn(await letter([]), 1);
    const own = new Set(letterhead.slice(0, -2).map((run) => `${run.text}@${run.y}`));
    return (await textOn(pdf, 1)).filter((run) => !own.has(`${run.text}@${run.y}`));
  };

  /** Only the body: what is set at its size. */
  const bodyOf = async (pdf: Uint8Array) => (await added(pdf)).filter((run) => run.size === 11.6);

  it('is one A4 page on the temple’s letterhead', async () => {
    const pdf = await letter(sampleBody);

    expect(await pageCount(pdf)).toBe(1);
    const size = await pageSize(pdf, 1);
    expect(size.width).toBeCloseTo(595.276, 3);
    expect(size.height).toBeCloseTo(841.89, 3);
    const texts = (await textOn(pdf, 1)).map((run) => run.text);
    expect(texts).toContain('To Whom It May Concern');
    expect(texts).toContain('Sincerely,');
  });

  it('breaks and places every line of the temple’s own letter as that letter has it', async () => {
    const body = await bodyOf(await letter(sampleBody));

    expect(body.map((run) => plain(run.text))).toEqual(sampleLines.map(([text]) => text));
    body.forEach((run, index) => {
      const [text, baseline, width] = sampleLines[index]!;
      expect(run.x, text).toBe(bodyLeft);
      // The temple's file rounds each line's drop, and each glyph's width, a little.
      expect(Math.abs(run.y - baseline), text).toBeLessThan(0.01);
      expect(Math.abs(run.width - width), text).toBeLessThan(0.15);
    });
  });

  // A font cut down to the letters used has come out with most of these blank.
  it.each([
    ['regular', {}],
    ['bold', { bold: true }],
    ['italic', { italic: true }],
    ['bold italic', { bold: true, italic: true }],
  ])('draws the letters it places in %s', async (_, marks) => {
    const letters = [...'aeghilmorsuy'];
    const pdf = await letter(
      letters.map((char) => ({ runs: [{ text: char.repeat(30), ...marks }] })),
    );
    const colour = await colourAt(pdf, 1);

    letters.forEach((char, line) => {
      // Across the line, a third of the way up its small letters.
      const y = 646.2202 - line * 17.0038 + 2;
      const inked = Array.from({ length: 400 }, (_, step) =>
        colour(bodyLeft + step * 0.25, y),
      ).filter((found) => found[0] < 128);
      expect(inked.length, char).toBeGreaterThan(30);
    });
  });

  it('sets each face in a font of its own', async () => {
    const word = 'dedicated volunteer';
    const widths = new Set<number>();
    for (const marks of [{}, { bold: true }, { italic: true }, { bold: true, italic: true }]) {
      const [run] = await bodyOf(await letter([{ runs: [{ text: word, ...marks }] }]));
      widths.add(run!.width);
    }

    // Four faces, four widths: none was set in another.
    expect(widths.size).toBe(4);
  });

  it('writes the number in red, ending where the temple’s does', async () => {
    const pdf = await letter(sampleBody);
    const number = (await added(pdf)).find((run) => run.text.startsWith('No.'))!;

    expect(number).toMatchObject({ text: 'No. 195956', y: 702.792, size: 16 });
    expect(number.x + number.width).toBeCloseTo(555.764, 2);
    // Somewhere across the "N", half way up it.
    const colour = await colourAt(pdf, 1);
    const across = [0.5, 1, 1.5, 2, 2.5, 3].map((step) => colour(number.x + step, 707));
    expect(across.some((found) => near(found, [194, 42, 27]))).toBe(true);
  });

  it('keeps a longer number’s end in the same place', async () => {
    const number = (await added(await letter(sampleBody, '12345678'))).find((run) =>
      run.text.startsWith('No.'),
    )!;

    expect(number.text).toBe('No. 12345678');
    expect(number.x + number.width).toBeCloseTo(555.764, 2);
  });

  it('writes the last day it holds as the temple does', async () => {
    const date = (await added(await letter(sampleBody))).find((run) =>
      run.text.startsWith('Valid'),
    )!;

    expect(date).toMatchObject({
      text: 'Valid Until Jul 16, 2027',
      x: 49.443,
      y: 701.642,
      size: 14,
    });
  });

  it('gives an empty line the room of one line', async () => {
    const body = await bodyOf(await letter(paragraphs('First.', 'Second.')));

    expect(body).toMatchObject([
      { text: 'First.', x: bodyLeft, y: 646.22 },
      { text: 'Second.', x: bodyLeft },
    ]);
    expect(body[1]!.y).toBeCloseTo(646.2202 - 2 * 17.0038, 3);
  });

  it('gives a line of spaces alone the room of one line too', async () => {
    const body = await bodyOf(
      await letter([
        { runs: [{ text: 'First.' }] },
        { runs: [{ text: '   ' }] },
        { runs: [{ text: 'Second.' }] },
      ]),
    );

    expect(body[1]!.y).toBeCloseTo(646.2202 - 2 * 17.0038, 3);
    expect(renderer.spareLines([{ runs: [{ text: 'First.' }] }, { runs: [{ text: '   ' }] }])).toBe(
      23,
    );
  });

  it('draws a fraction as wide as it measured it', async () => {
    // The font has small figures for either side of a fraction slash, which
    // setting a character at a time does not use.
    const body = await bodyOf(
      await letter([
        { runs: [{ text: 'Mix 1\u20442 and 3\u20444 cups' }, { text: ' now', bold: true }] },
      ]),
    );
    const [fraction, after] = body;

    // What follows starts where the fraction, as drawn, ends, plus a space.
    expect(after!.x - (fraction!.x + fraction!.width)).toBeGreaterThan(2);
    expect(after!.x - (fraction!.x + fraction!.width)).toBeLessThan(4);
  });

  it('sets bold and italic in their own faces, one after the other', async () => {
    const body = await bodyOf(
      await letter([
        {
          runs: [
            { text: 'She is a ' },
            { text: 'dedicated', bold: true },
            { text: ' and ' },
            { text: 'kind', italic: true },
            { text: ' volunteer.' },
          ],
        },
      ]),
    );

    expect(body.map((run) => plain(run.text))).toEqual([
      'She is a',
      'dedicated',
      'and',
      'kind',
      'volunteer.',
    ]);
    // Each starts where the one before it, and the space between them, ends.
    for (let index = 1; index < body.length; index++) {
      const before = body[index - 1]!;
      expect(body[index]!.x).toBeGreaterThan(before.x + before.width);
      expect(body[index]!.y).toBe(646.22);
    }
    // Bold is wider than the same word in regular.
    const regular = await bodyOf(await letter([{ runs: [{ text: 'dedicated' }] }]));
    expect(body[1]!.width).toBeGreaterThan(regular[0]!.width);
  });

  it('draws a rule under underlined words', async () => {
    const pdf = await letter([
      {
        runs: [{ text: 'Valid for ' }, { text: 'one hour', underline: true }, { text: ' in all.' }],
      },
    ]);
    const [line] = await bodyOf(pdf);
    const colour = await colourAt(pdf, 1);
    const white = [255, 255, 255];

    // Roboto asks for the top of its underline 0.85 points under the baseline
    // and for a rule 0.57 thick: its middle is 1.13 down.
    const under = (x: number) =>
      [0.9, 1.0, 1.1, 1.2, 1.3]
        .map((down) => colour(x, 646.2202 - down))
        .reduce((darkest, found) => (found[0] < darkest[0] ? found : darkest));
    expect(near(colour(bodyLeft + 60, 646.2202 - 0.3), white)).toBe(true);
    expect(plain(line!.text)).toBe('Valid for one hour in all.');
    expect(near(under(bodyLeft + 60), [44, 46, 53])).toBe(true);
    expect(near(under(bodyLeft + 20), white)).toBe(true);
    expect(near(under(bodyLeft + 110), white)).toBe(true);
  });

  it('hangs the lines of a list item in from its bullet', async () => {
    const long =
      'Assisting the elderly and visitors with daily activities at the monastery, ' +
      'during prayers and on festival days, with patience and care';
    const body = await bodyOf(
      await letter([
        { runs: [{ text: 'She has helped with:' }] },
        { bullet: true, runs: [{ text: long }] },
        { bullet: true, runs: [{ text: 'Cooking' }] },
      ]),
    );

    expect(body.map((run) => [plain(run.text).split(' ')[0], run.x])).toEqual([
      ['She', bodyLeft],
      ['•', bodyLeft],
      ['Assisting', 63.795],
      ['festival', 63.795],
      ['•', bodyLeft],
      ['Cooking', 63.795],
    ]);
    // No line of the item runs past the body's right edge.
    for (const run of body) expect(run.x + run.width).toBeLessThanOrEqual(bodyRight);
  });

  describe('bodies it cannot print', () => {
    it('prints the temple’s own letter, and one that fills the page', () => {
      expect(renderer.bodyProblem(sampleBody)).toBeUndefined();
      expect(renderer.bodyProblem(Array(25).fill({ runs: [{ text: 'A line.' }] }))).toBeUndefined();
    });

    it('says how many lines too long a body is, counting empty ones', () => {
      const lines: LetterBody = Array(26).fill({ runs: [{ text: 'A line.' }] });

      expect(renderer.bodyProblem(lines)).toEqual({ kind: 'tooLong', lines: 1 });
      expect(renderer.bodyProblem([...sampleBody, { runs: [] }, ...sampleBody])).toEqual({
        kind: 'tooLong',
        lines: 22,
      });
    });

    it('refuses letters its font does not have', () => {
      expect(renderer.bodyProblem(paragraphs('བཀྲ་ཤིས་བདེ་ལེགས།'))).toEqual({
        kind: 'unsupported',
      });
    });

    it('cuts a word wider than the page instead of running off it', async () => {
      const body = await bodyOf(await letter(paragraphs('W'.repeat(60))));

      expect(body.length).toBe(2);
      for (const run of body) expect(run.x + run.width).toBeLessThanOrEqual(bodyRight);
    });
  });

  it('refuses a template that does not exist', async () => {
    await expect(letterRenderer('nowhere')).rejects.toThrow('No letter template named "nowhere".');
  });
});
