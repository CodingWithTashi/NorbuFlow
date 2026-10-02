import fontkit from '@pdf-lib/fontkit';
import {
  appendBezierCurve,
  clip,
  closePath,
  endPath,
  lineTo,
  moveTo,
  PDFDocument,
  type PDFFont,
  type PDFPage,
  popGraphicsState,
  pushGraphicsState,
  rgb,
  setCharacterSpacing,
} from 'pdf-lib';

import type { CalendarDate } from '../../core/calendar-date';
import type { Anchor, CardTemplate, FontKey, TextColumn, TextStyle } from './card-template';

export interface CardDetails {
  name: string;
  number: string;
  validUntil: CalendarDate;
  /** A JPEG. Any size or shape: it is scaled to cover the photo box. */
  photo: Uint8Array;
}

/** Why a name cannot be printed on the card. */
export type NameProblem = 'unsupported' | 'tooLong';

/** What a card printer makes use of, with room to spare: 600 dots per inch. */
const photoDotsPerPoint = 600 / 72;

// The designer's text has neither kerning nor ligatures, so neither is applied here.
const plainText = { kern: false, liga: false };

// How far a Bézier handle sits from a corner to draw a quarter circle.
const quarterCircle = 0.5522847;

export type Fonts = Record<FontKey, PDFFont>;

/**
 * Fills a card template with one member's details and returns a two-page PDF
 * (front, back) at the artwork's size. No Firebase: it can run anywhere.
 */
export class CardRenderer {
  private constructor(
    private readonly template: CardTemplate,
    private readonly front: PDFDocument,
    private readonly back: PDFDocument,
    /** For measuring. Each card embeds its own copy of the fonts. */
    private readonly fonts: Fonts,
  ) {}

  static async load(template: CardTemplate): Promise<CardRenderer> {
    const [front, back, scratch] = await Promise.all([
      PDFDocument.load(template.front),
      PDFDocument.load(template.back),
      PDFDocument.create(),
    ]);
    return new CardRenderer(template, front, back, await embedFonts(scratch, template));
  }

  /** The size to prepare a photo at before handing it to `render`. */
  get photoPixels(): { width: number; height: number } {
    const { width, height } = this.template.photo;
    return {
      width: Math.round(width * photoDotsPerPoint),
      height: Math.round(height * photoDotsPerPoint),
    };
  }

  /** Why `name` cannot be printed, or `undefined` if it can. */
  nameProblem(name: string): NameProblem | undefined {
    return textProblem(this.fonts, this.template.name, name);
  }

  async render(details: CardDetails): Promise<Uint8Array> {
    const { template } = this;
    const pdf = await PDFDocument.create();
    const [[front], [back], fonts, photo] = await Promise.all([
      pdf.copyPages(this.front, [0]),
      pdf.copyPages(this.back, [0]),
      embedFonts(pdf, template),
      pdf.embedJpg(details.photo),
    ]);
    if (!front || !back) throw new Error('A card template needs a front and a back page.');
    pdf.addPage(front);
    pdf.addPage(back);

    const box = template.photo;
    const scale = Math.max(box.width / photo.width, box.height / photo.height);
    const width = photo.width * scale;
    const height = photo.height * scale;
    front.pushOperators(pushGraphicsState(), ...roundedRect(box), clip(), endPath());
    front.drawImage(photo, {
      x: box.x + (box.width - width) / 2,
      y: box.y + (box.height - height) / 2,
      width,
      height,
    });
    front.pushOperators(popGraphicsState());

    const { name, validity, numberLabel, number } = template;
    const lines = wrap(fonts, name, details.name);
    lines.forEach((line, index) => {
      drawCentred(front, fonts, name, line, name.baseline - index * name.lineHeight);
    });
    const lastBaseline = name.baseline - (lines.length - 1) * name.lineHeight;
    drawCentred(
      front,
      fonts,
      validity,
      validity.text(details.validUntil),
      lastBaseline - validity.below,
    );
    place(front, fonts, numberLabel, numberLabel.text);
    place(front, fonts, number, details.number);

    return pdf.save();
  }
}

/** The fonts a card is set in, embedded in `pdf`. */
export async function embedFonts(
  pdf: PDFDocument,
  template: Pick<CardTemplate, 'fonts'>,
): Promise<Fonts> {
  pdf.registerFontkit(fontkit);
  const embed = (key: FontKey) =>
    pdf.embedFont(template.fonts[key], { subset: true, features: plainText });
  const [regular, bold] = await Promise.all([embed('regular'), embed('bold')]);
  return { regular, bold };
}

function place(page: PDFPage, fonts: Fonts, style: TextStyle & Anchor, text: string): void {
  if ('column' in style) {
    drawCentred(page, fonts, { ...style, ...style.column }, text, style.baseline);
  } else {
    draw(page, fonts, style, text, style.x, style.baseline);
  }
}

/** Why `text` cannot be set in `style`'s column on `maxLines` lines, if it cannot. */
export function textProblem(
  fonts: Fonts,
  style: TextStyle & TextColumn & { maxLines: number },
  text: string,
): NameProblem | undefined {
  const supported = new Set(fonts[style.font].getCharacterSet());
  if ([...text].some((char) => !supported.has(char.codePointAt(0)!))) return 'unsupported';

  const lines = wrap(fonts, style, text);
  const fits = lines.every((line) => widthOf(fonts, style, line) <= style.width);
  return fits && lines.length <= style.maxLines ? undefined : 'tooLong';
}

/** The width of `text` as `draw` sets it, letter spacing included. */
function widthOf(fonts: Fonts, style: TextStyle, text: string): number {
  const spacing = [...text].length * style.letterSpacing * style.size;
  return fonts[style.font].widthOfTextAtSize(text, style.size) + spacing;
}

function draw(
  page: PDFPage,
  fonts: Fonts,
  style: TextStyle,
  text: string,
  x: number,
  baseline: number,
): void {
  const [red, green, blue] = style.color;
  page.pushOperators(pushGraphicsState(), setCharacterSpacing(style.letterSpacing * style.size));
  page.drawText(text, {
    x,
    y: baseline,
    size: style.size,
    font: fonts[style.font],
    color: rgb(red, green, blue),
  });
  page.pushOperators(popGraphicsState());
}

export function drawCentred(
  page: PDFPage,
  fonts: Fonts,
  style: TextStyle & TextColumn,
  text: string,
  baseline: number,
): void {
  const margin = (style.width - widthOf(fonts, style, text)) / 2;
  const x = style.x + Math.floor(margin / style.snap) * style.snap;
  draw(page, fonts, style, text, x, baseline);
}

/** Breaks `text` between words so that each line fits the column if it can. */
export function wrap(fonts: Fonts, style: TextStyle & TextColumn, text: string): string[] {
  const lines: string[] = [];
  for (const word of text.trim().split(/\s+/)) {
    const last = lines.at(-1);
    if (last !== undefined && widthOf(fonts, style, `${last} ${word}`) <= style.width) {
      lines[lines.length - 1] = `${last} ${word}`;
    } else {
      lines.push(word);
    }
  }
  return lines;
}

function roundedRect(box: { x: number; y: number; width: number; height: number; radius: number }) {
  const { x, y, radius } = box;
  const right = x + box.width;
  const top = y + box.height;
  const handle = radius * (1 - quarterCircle);
  return [
    moveTo(x + radius, y),
    lineTo(right - radius, y),
    appendBezierCurve(right - handle, y, right, y + handle, right, y + radius),
    lineTo(right, top - radius),
    appendBezierCurve(right, top - handle, right - handle, top, right - radius, top),
    lineTo(x + radius, top),
    appendBezierCurve(x + handle, top, x, top - handle, x, top - radius),
    lineTo(x, y + radius),
    appendBezierCurve(x, y + handle, x + handle, y, x + radius, y),
    closePath(),
  ];
}
