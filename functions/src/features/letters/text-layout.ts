import type { LetterBody, LetterLine } from './letter';

/** The four faces a letter's body is set in. */
export type BodyFace = 'regular' | 'bold' | 'italic' | 'boldItalic';

/** How wide a font sets text. Widths are in ems. */
export interface FaceMetrics {
  /** Each character's own advance, and its advance once kerned toward the next. */
  measure(text: string): { own: number[]; kerned: number[] };
  supports(char: string): boolean;
}

/** Where the body goes on the page, in points. */
export interface BodyBox {
  x: number;
  width: number;
  /** The baseline of the first line. */
  baseline: number;
  /** Distance between the baselines of two lines. */
  lineHeight: number;
  /** More lines than this would run into what is printed below. */
  maxLines: number;
  size: number;
  /** How far a list item's text stands in from its bullet. */
  listIndent: number;
}

/** A stretch of one printed line in one face, starting at `x`. */
export interface PlacedRun {
  face: BodyFace;
  underline: boolean;
  text: string;
  x: number;
  width: number;
  /** What kerning adds after each character, in ems. Mostly zero or less. */
  kerning: number[];
}

export interface PlacedLine {
  baseline: number;
  runs: PlacedRun[];
  /** Where a list item's bullet sits, on its first line. */
  bulletAt?: number;
}

export interface BodyLayout {
  lines: PlacedLine[];
  /** How many lines more than the page has room for. */
  overflow: number;
  /** How many more lines the page has room for. */
  spare: number;
}

export const bullet = '•';

interface Character {
  char: string;
  face: BodyFace;
  underline: boolean;
  own: number;
  kerned: number;
}

/** Whether `body` has a character its fonts cannot print. */
export function unprintable(body: LetterBody, faces: Record<BodyFace, FaceMetrics>): boolean {
  return body.some((line) =>
    line.runs.some((run) => [...run.text].some((char) => !faces[faceOf(run)].supports(char))),
  );
}

/**
 * Sets `body` in `box`: a line that is too wide breaks between words, and an
 * empty line takes the room of one line.
 */
export function layOut(
  body: LetterBody,
  faces: Record<BodyFace, FaceMetrics>,
  box: BodyBox,
): BodyLayout {
  const lines: PlacedLine[] = [];
  let slot = 0;
  for (const line of body) {
    const characters = charactersOf(line, faces);
    // A line of nothing, or of spaces alone, is an empty line.
    if (characters.every(isSpace)) {
      slot++;
      continue;
    }
    const indent = line.bullet ? box.listIndent : 0;
    const rows = wrap(characters, (box.width - indent) / box.size);
    rows.forEach((row, index) => {
      lines.push({
        baseline: box.baseline - slot * box.lineHeight,
        runs: runsOf(row, box.x + indent, box.size),
        ...(line.bullet && index === 0 ? { bulletAt: box.x } : {}),
      });
      slot++;
    });
  }
  return {
    lines,
    overflow: Math.max(0, slot - box.maxLines),
    spare: Math.max(0, box.maxLines - slot),
  };
}

function faceOf(run: { bold?: boolean; italic?: boolean }): BodyFace {
  if (run.bold) return run.italic ? 'boldItalic' : 'bold';
  return run.italic ? 'italic' : 'regular';
}

/** A line's characters with their widths. Kerning runs across runs of one face. */
function charactersOf(line: LetterLine, faces: Record<BodyFace, FaceMetrics>): Character[] {
  const characters: Character[] = line.runs.flatMap((run) =>
    [...run.text].map((char) => ({
      char,
      face: faceOf(run),
      underline: run.underline ?? false,
      own: 0,
      kerned: 0,
    })),
  );
  let start = 0;
  while (start < characters.length) {
    const face = characters[start]!.face;
    let end = start;
    while (end < characters.length && characters[end]!.face === face) end++;
    const stretch = characters.slice(start, end);
    const { own, kerned } = faces[face].measure(stretch.map((c) => c.char).join(''));
    stretch.forEach((character, index) => {
      character.own = own[index]!;
      character.kerned = kerned[index]!;
    });
    start = end;
  }
  return characters;
}

/** The width of a row in ems. Its last character has nothing to kern toward. */
function widthOf(row: Character[]): number {
  return row.reduce(
    (width, character, index) =>
      width + (index === row.length - 1 ? character.own : character.kerned),
    0,
  );
}

const isSpace = (character: Character) => character.char === ' ';

/** Fills each row with as many words as fit in `room` ems. */
function wrap(characters: Character[], room: number): Character[][] {
  const rows: Character[][] = [];
  let row: Character[] = [];
  let index = 0;
  while (index < characters.length) {
    // The spaces before a word, then the word.
    let end = index;
    while (end < characters.length && isSpace(characters[end]!)) end++;
    const wordAt = end;
    while (end < characters.length && !isSpace(characters[end]!)) end++;
    let word = characters.slice(wordAt, end);

    if (word.length === 0) break;
    if (row.length > 0 && widthOf([...row, ...characters.slice(index, end)]) <= room) {
      row.push(...characters.slice(index, end));
    } else {
      if (row.length > 0) rows.push(row);
      // A word wider than the page is cut where it stops fitting.
      while (widthOf(word) > room && word.length > 1) {
        let fits = 1;
        while (fits < word.length && widthOf(word.slice(0, fits + 1)) <= room) fits++;
        rows.push(word.slice(0, fits));
        word = word.slice(fits);
      }
      row = word;
    }
    index = end;
  }
  if (row.length > 0) rows.push(row);
  return rows;
}

/** Splits a row where the face or the underline changes. */
function runsOf(row: Character[], x: number, size: number): PlacedRun[] {
  const runs: PlacedRun[] = [];
  let left = x;
  let start = 0;
  while (start < row.length) {
    const { face, underline } = row[start]!;
    let end = start;
    while (end < row.length && row[end]!.face === face && row[end]!.underline === underline) end++;
    const stretch = row.slice(start, end);
    const last = end === row.length;
    runs.push({
      face,
      underline,
      text: stretch.map((c) => c.char).join(''),
      x: left,
      width: widthOf(stretch) * size,
      kerning: stretch.map((c) => c.kerned - c.own),
    });
    // The next run starts where this one's last character, kerned, ends.
    left += (last ? widthOf(stretch) : stretch.reduce((sum, c) => sum + c.kerned, 0)) * size;
    start = end;
  }
  return runs;
}
