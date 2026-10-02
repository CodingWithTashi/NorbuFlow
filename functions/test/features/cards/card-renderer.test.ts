import { beforeAll, describe, expect, it } from 'vitest';

import { cardRenderer, type CardRenderer } from '../../../src/features/cards';
import { colourAt, pageCount, pageSize, textOn } from '../../support/pdf';
import { photo, photoColour } from '../../support/photos';

// The positions asserted here are the ones Canva gives the temple's own cards.
// If one changes, the printed card no longer matches the design.
describe('the Drepung Loseling Canada card', () => {
  let renderer: CardRenderer;
  let picture: Uint8Array;
  const validUntil = { year: 2027, month: 7, day: 31 };

  beforeAll(async () => {
    renderer = await cardRenderer('drepung-loseling-canada');
    picture = await photo(renderer.photoPixels.width, renderer.photoPixels.height);
  });

  const card = (name: string, number = '194915308') =>
    renderer.render({ name, number, validUntil, photo: picture });

  /** Whether a colour is the test photo's, give or take JPEG compression. */
  const isPhoto = (colour: readonly number[]) =>
    colour.reduce((off, value, index) => off + Math.abs(value - photoColour[index]!), 0) < 12;

  it('is two pages, front then back, at the size of the artwork', async () => {
    const pdf = await card('Tenzin Dolma');

    expect(await pageCount(pdf)).toBe(2);
    for (const page of [1, 2]) {
      const size = await pageSize(pdf, page);
      expect(size.width).toBeCloseTo(159.75, 3);
      expect(size.height).toBeCloseTo(252, 3);
    }
    const back = await textOn(pdf, 2);
    expect(back.map((run) => run.text)).toContain('If found please return to:');
  });

  it('sets the member details where the design has them', async () => {
    const front = await textOn(await card('Tenzin Dolma'), 1);

    expect(front).toMatchObject([
      // Part of the artwork, so untouched.
      { text: 'Drepung Loseling Canada', x: 34.441, y: 190.545, size: 7.639 },
      { text: 'Tenzin Dolma', x: 50.55, y: 69.219, size: 8.987 },
      { text: 'Valid: 2027-July-31', x: 55.57, y: 61.73, size: 5.991, width: 51.08 },
      { text: 'Membership number', x: 64.403, y: 39.665, size: 4.993, width: 49.668 },
      { text: '194915308', x: 64.403, y: 28.848, size: 9.985 },
    ]);
  });

  it('wraps a long name onto a second line and moves the validity down', async () => {
    const front = await textOn(await card('Tsering Yangzom Wangmo'), 1);

    expect(front.slice(1, 4)).toMatchObject([
      { text: 'Tsering Yangzom', x: 43.085, y: 69.219, size: 8.987 },
      { text: 'Wangmo', x: 61.339, y: 60.232, size: 8.987 },
      { text: 'Valid: 2027-July-31', x: 55.57, y: 52.743, size: 5.991 },
    ]);
  });

  it('fills the photo box and rounds its corners', async () => {
    const colour = await colourAt(await card('Tenzin Dolma'), 1);

    // The box runs from (40.39, 87.70) to (119.84, 178.14).
    expect(isPhoto(colour(80, 133))).toBe(true);
    expect(isPhoto(colour(41.5, 133))).toBe(true);
    expect(isPhoto(colour(80, 177))).toBe(true);
    // Inside the box's rectangle but outside its rounded corner.
    expect(isPhoto(colour(40.8, 177.7))).toBe(false);
    // Just outside the box.
    expect(isPhoto(colour(39.5, 133))).toBe(false);
  });

  it('covers the box with a photo of another shape instead of stretching it', async () => {
    const wide = await photo(900, 300);
    const colour = await colourAt(
      await renderer.render({ name: 'Tenzin Dolma', number: '1', validUntil, photo: wide }),
      1,
    );

    const edges = [colour(80, 90), colour(80, 176), colour(42, 133), colour(118, 133)];
    expect(edges.map(isPhoto)).toEqual([true, true, true, true]);
  });

  describe('names it cannot print', () => {
    it('accepts a name that fits on one or two lines', () => {
      expect(renderer.nameProblem('Tenzin Dolma')).toBeUndefined();
      expect(renderer.nameProblem('Tsering Yangzom Wangmo')).toBeUndefined();
      expect(renderer.nameProblem("Marie-Ève O'Brien")).toBeUndefined();
    });

    it('refuses a name that needs a third line', () => {
      expect(renderer.nameProblem('Tenzin Lobsang Kunchok Dhondup Wangchuk Tsering')).toBe(
        'tooLong',
      );
    });

    it('refuses a single word wider than the card', () => {
      expect(renderer.nameProblem('Tenzinlobsangkunchokdhondupwangchuk')).toBe('tooLong');
    });

    it('refuses letters the card font does not have', () => {
      expect(renderer.nameProblem('བསྟན་འཛིན་')).toBe('unsupported');
    });
  });
});
