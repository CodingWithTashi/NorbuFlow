import { beforeAll, describe, expect, it } from 'vitest';

import { InMemoryFileStore } from '../../../src/core/file-store';
import {
  cardRenderer,
  type CardRenderer,
  type CardTemple,
  templeNameProblem,
} from '../../../src/features/cards';
import { loselingCard } from '../../support/database';
import { colourAt, pageCount, pageSize, textOn } from '../../support/pdf';
import { photo, photoColour } from '../../support/photos';

// The positions asserted here are the ones Canva gives the temple's own cards.
// If one changes, the printed card no longer matches the design.
describe('the Drepung Loseling Canada card', () => {
  let renderer: CardRenderer;
  let picture: Uint8Array;
  const validUntil = { year: 2027, month: 7, day: 31 };

  beforeAll(async () => {
    renderer = await cardRenderer(loselingCard, new InMemoryFileStore());
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

// NorbuFlow's own layout, for a temple with no design of its own. The
// positions here are the design: there is no artwork to compare against.
describe('the standard card', () => {
  const drolmaLing: CardTemple = {
    id: 'drolma-ling',
    name: 'Drolma Ling Centre',
    cardTemplate: 'standard',
    logoKey: null,
  };
  const validUntil = { year: 2027, month: 10, day: 1 };
  const maroon = [122, 31, 43];
  const white = [255, 255, 255];
  let files: InMemoryFileStore;
  let picture: Uint8Array;

  const card = async (temple: CardTemple, name = 'Tenzin Dolma', number = 'DL-0142') => {
    const renderer = await cardRenderer(temple, files);
    return renderer.render({ name, number, validUntil, photo: picture });
  };

  /** Whether two colours are the same, give or take how a page is drawn. */
  const near = (colour: readonly number[], other: readonly number[]) =>
    colour.every((value, index) => Math.abs(value - other[index]!) < 6);

  /** How far the middle of a run of text is from the middle of the card. */
  const offCentre = (run: { x: number; width: number }) =>
    Math.abs(run.x + run.width / 2 - 159.75 / 2);

  beforeAll(async () => {
    files = new InMemoryFileStore();
    await files.put('logo-blue', await photo(300, 300, 'png'), 'image/png');
    const renderer = await cardRenderer(drolmaLing, files);
    picture = await photo(renderer.photoPixels.width, renderer.photoPixels.height);
  });

  it('is the size of a designed card, with a photo of the same shape', async () => {
    const pdf = await card(drolmaLing);

    expect(await pageCount(pdf)).toBe(2);
    for (const page of [1, 2]) {
      const size = await pageSize(pdf, page);
      expect(size.width).toBeCloseTo(159.75, 3);
      expect(size.height).toBeCloseTo(252, 3);
    }
    // The app crops every photo to one shape, whichever card the temple prints.
    const designed = await cardRenderer(loselingCard, files);
    expect((await cardRenderer(drolmaLing, files)).photoPixels).toEqual(designed.photoPixels);
  });

  it('carries the temple’s name and the member’s details, each centred', async () => {
    const front = await textOn(await card(drolmaLing), 1);

    expect(front).toMatchObject([
      { text: 'Drolma Ling Centre', y: 214.144, size: 8 },
      { text: 'Tenzin Dolma', y: 67, size: 10 },
      { text: 'Valid until 1 October 2027', y: 57.5, size: 6.5 },
      { text: 'Membership number', y: 24.5, size: 5 },
      { text: 'DL-0142', y: 11, size: 11 },
    ]);
    for (const run of front) expect(offCentre(run), run.text).toBeLessThan(0.02);
  });

  it('wraps a long member name and moves the validity down', async () => {
    const front = await textOn(await card(drolmaLing, 'Tsering Yangzom Wangmo Dolkar'), 1);

    expect(front.slice(1, 4)).toMatchObject([
      { text: 'Tsering Yangzom Wangmo', y: 67 },
      { text: 'Dolkar', y: 56 },
      { text: 'Valid until 1 October 2027', y: 46.5 },
    ]);
  });

  it('sets a long temple name on two lines', async () => {
    const temple = { ...drolmaLing, name: 'Jangchub Choling Tibetan Buddhist Meditation Centre' };

    const front = await textOn(await card(temple), 1);

    expect(front.slice(0, 2)).toMatchObject([
      { text: 'Jangchub Choling Tibetan Buddhist', y: 218.944 },
      { text: 'Meditation Centre', y: 209.344 },
    ]);
  });

  it('says where to return the card on the back', async () => {
    const back = await textOn(await card(drolmaLing), 2);

    expect(back.map((run) => run.text)).toEqual([
      // Set wide apart, so a reader of the PDF takes it letter by letter.
      'M E M B E R S H I P C A R D',
      'If found, please return this card to',
      'Drolma Ling Centre',
    ]);
  });

  it('shows the temple’s logo on a white disc, with the name under it', async () => {
    const withLogo = { ...drolmaLing, id: 'with-logo', logoKey: 'logo-blue' };
    const pdf = await card(withLogo);
    const front = await colourAt(pdf, 1);
    const back = await colourAt(pdf, 2);

    // The disc is 17 points around (79.9, 229); the logo fills its middle.
    expect(near(front(79.9, 229), photoColour)).toBe(true);
    expect(near(front(79.9, 244), white)).toBe(true);
    expect(near(front(79.9, 249), maroon)).toBe(true);
    expect(near(back(79.9, 186), photoColour)).toBe(true);
    expect((await textOn(pdf, 1))[0]).toMatchObject({ text: 'Drolma Ling Centre', y: 194.144 });

    // With no logo the header is plain.
    expect(near((await colourAt(await card(drolmaLing), 1))(79.9, 229), maroon)).toBe(true);
  });

  it('is drawn afresh when the temple’s name or logo changes', async () => {
    const renamed = { ...drolmaLing, name: 'Drolma Ling Vancouver' };

    expect((await textOn(await card(renamed), 1))[0]?.text).toBe('Drolma Ling Vancouver');
    expect((await textOn(await card(drolmaLing), 1))[0]?.text).toBe('Drolma Ling Centre');

    // The same temple, given a logo: the header that was plain now carries it.
    const withLogo = { ...drolmaLing, logoKey: 'logo-blue' };
    expect(near((await colourAt(await card(withLogo), 1))(79.9, 229), photoColour)).toBe(true);
    expect(near((await colourAt(await card(drolmaLing), 1))(79.9, 229), maroon)).toBe(true);
  });

  it('tries again after failing to fetch the logo', async () => {
    const temple = { ...drolmaLing, id: 'late-logo', logoKey: 'logo-late' };
    await expect(card(temple)).rejects.toThrow('No file is stored as "logo-late".');

    await files.put('logo-late', await photo(64, 64, 'png'), 'image/png');

    expect(await pageCount(await card(temple))).toBe(2);
  });

  describe('temple names it cannot print', () => {
    it('accepts a name of one or two lines', async () => {
      expect(await templeNameProblem('standard', 'Drolma Ling Centre')).toBeUndefined();
      expect(
        await templeNameProblem('standard', 'Jangchub Choling Tibetan Buddhist Meditation Centre'),
      ).toBeUndefined();
    });

    it('refuses a name that needs a third line, or letters the font does not have', async () => {
      const long =
        'The Jangchub Choling Tibetan Buddhist Meditation and Cultural Centre of Ontario';

      expect(await templeNameProblem('standard', long)).toBe('tooLong');
      expect(await templeNameProblem('standard', 'སྒྲོལ་མ་གླིང་།')).toBe('unsupported');
    });

    it('has no say over a designed card, whose artwork already names the temple', async () => {
      expect(await templeNameProblem('drepung-loseling-canada', 'སྒྲོལ་མ་གླིང་།')).toBeUndefined();
    });
  });
});
