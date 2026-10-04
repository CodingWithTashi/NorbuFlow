import fontkit, { type Font } from '@pdf-lib/fontkit';
import {
  beginText,
  endText,
  PDFDocument,
  type PDFFont,
  type PDFName,
  PDFOperator,
  PDFOperatorNames,
  type PDFPage,
  rgb,
  setFillingRgbColor,
  setFontAndSize,
  setTextMatrix,
} from 'pdf-lib';

import type { CalendarDate } from '../../core/calendar-date';
import type { LetterBody } from './letter';
import type { Colour, LetterFace, LetterTemplate } from './letter-template';
import {
  type BodyFace,
  type BodyLayout,
  bullet,
  type FaceMetrics,
  layOut,
  unprintable,
} from './text-layout';

export interface LetterDetails {
  /** The digits of its number. */
  number: string;
  validUntil: CalendarDate;
  body: LetterBody;
}

/** Why a body cannot be printed: letters the font lacks, or `lines` too many. */
export type BodyProblem = { kind: 'unsupported' } | { kind: 'tooLong'; lines: number };

// Kerning is worked out here and written into the PDF; the designs use no ligatures.
const shaping = { kern: true, liga: false };
const embedding = { kern: false, liga: false };

/** A font as the layout measures it. */
class Face implements FaceMetrics {
  constructor(
    readonly font: Font,
    private readonly kerns: (first: string, second: string) => boolean,
  ) {}

  /** Each character as it is drawn, on its own: its glyph and its advance in ems. */
  private readonly alone = new Map<string, { glyph?: number; advance: number }>();

  private drawn(char: string): { glyph?: number; advance: number } {
    let drawn = this.alone.get(char);
    if (!drawn) {
      const run = this.font.layout(char, embedding);
      const glyph = run.glyphs.length === 1 ? run.glyphs[0]!.id : undefined;
      drawn = { glyph, advance: run.advanceWidth / this.font.unitsPerEm };
      this.alone.set(char, drawn);
    }
    return drawn;
  }

  measure(text: string): { own: number[]; kerned: number[] } {
    const chars = [...text];
    const em = this.font.unitsPerEm;
    const run = this.font.layout(text, shaping);
    const own = chars.map((char) => this.drawn(char).advance);
    // Text is drawn a character at a time. Where the stretch as a whole takes
    // other glyphs (joined letters, a fraction's figures) it is measured so too.
    const asDrawn =
      run.glyphs.length === chars.length &&
      run.glyphs.every((glyph, index) => glyph.id === this.drawn(chars[index]!).glyph);
    if (!asDrawn) return { own, kerned: own };

    const kerned = run.positions.map((position, index) => {
      const next = chars[index + 1];
      return next !== undefined && this.kerns(chars[index]!, next)
        ? position.xAdvance / em
        : own[index]!;
    });
    return { own, kerned };
  }

  supports(char: string): boolean {
    return this.font.hasGlyphForCodePoint(char.codePointAt(0)!);
  }
}

/**
 * Sets a letter's number, date and body on a temple's letterhead and returns
 * a one-page PDF. No Firebase: it can run anywhere.
 */
export class LetterRenderer {
  private constructor(
    private readonly template: LetterTemplate,
    private readonly page: PDFDocument,
    private readonly faces: Record<LetterFace, Face>,
  ) {}

  static async load(template: LetterTemplate): Promise<LetterRenderer> {
    const face = (key: LetterFace, kerns: (first: string, second: string) => boolean) =>
      new Face(fontkit.create(template.fonts[key]), kerns);
    return new LetterRenderer(template, await PDFDocument.load(template.page), {
      regular: face('regular', template.body.kerned),
      bold: face('bold', template.body.kerned),
      italic: face('italic', template.body.kerned),
      boldItalic: face('boldItalic', template.body.kerned),
      display: face('display', () => true),
    });
  }

  /** Why `body` cannot be printed, or `undefined` if it can. */
  bodyProblem(body: LetterBody): BodyProblem | undefined {
    if (unprintable(body, this.faces)) return { kind: 'unsupported' };
    const { overflow } = this.layOut(body);
    return overflow > 0 ? { kind: 'tooLong', lines: overflow } : undefined;
  }

  /** How many lines of room the page has left under `body`. */
  spareLines(body: LetterBody): number {
    return this.layOut(body).spare;
  }

  async render(details: LetterDetails): Promise<Uint8Array> {
    const { template } = this;
    const pdf = await PDFDocument.create();
    pdf.registerFontkit(fontkit);
    const [page] = await pdf.copyPages(this.page, [0]);
    if (!page) throw new Error('A letter template needs a page.');
    pdf.addPage(page);

    const layout = this.layOut(details.body);
    const used = new Set<LetterFace>(['display']);
    for (const line of layout.lines) {
      if (line.bulletAt !== undefined) used.add('regular');
      for (const run of line.runs) used.add(run.face);
    }
    // A letter carries only the faces it uses, each whole: cut down to the
    // letter's own characters, Roboto comes out with most of them blank.
    const fonts = new Map<LetterFace, { font: PDFFont; key: PDFName }>();
    for (const key of used) {
      const font = await pdf.embedFont(template.fonts[key], { subset: false, features: embedding });
      fonts.set(key, { font, key: page.node.newFontDictionary(font.name, font.ref) });
    }
    const show = (
      face: LetterFace,
      text: string,
      at: { x: number; baseline: number; size: number; color: Colour },
      kerning: number[],
    ) => page.pushOperators(...showText(fonts.get(face)!, text, at, kerning));

    const { number, validUntil, body } = template;
    const digits = number.text(details.number);
    const numbered = this.faces.display.measure(digits);
    show(
      'display',
      digits,
      { ...number, x: number.right - sum(endingPlain(numbered)) * number.size },
      differences(numbered),
    );
    const date = validUntil.text(details.validUntil);
    show('display', date, validUntil, differences(this.faces.display.measure(date)));

    for (const line of layout.lines) {
      const at = { baseline: line.baseline, size: body.size, color: body.color };
      if (line.bulletAt !== undefined) show('regular', bullet, { ...at, x: line.bulletAt }, []);
      for (const run of line.runs) {
        show(run.face, run.text, { ...at, x: run.x }, run.kerning);
        if (run.underline) this.underline(page, run, line.baseline);
      }
    }
    return pdf.save();
  }

  private layOut(body: LetterBody): BodyLayout {
    return layOut(body, this.faces, this.template.body);
  }

  /** A rule under `run`, where and as thick as its font asks. */
  private underline(
    page: PDFPage,
    run: { face: BodyFace; x: number; width: number },
    baseline: number,
  ): void {
    const { font } = this.faces[run.face];
    const { size, color } = this.template.body;
    const scale = size / font.unitsPerEm;
    // A font gives where the rule's top edge goes; a line is drawn by its middle.
    const y = baseline + (font.underlinePosition - font.underlineThickness / 2) * scale;
    page.drawLine({
      start: { x: run.x, y },
      end: { x: run.x + run.width, y },
      thickness: font.underlineThickness * scale,
      color: rgb(...color),
    });
  }
}

const sum = (values: number[]) => values.reduce((total, value) => total + value, 0);

/** Each character's advance, the last one unkerned: nothing follows it. */
function endingPlain(measured: { own: number[]; kerned: number[] }): number[] {
  return measured.kerned.map((advance, index) =>
    index === measured.kerned.length - 1 ? measured.own[index]! : advance,
  );
}

const differences = (measured: { own: number[]; kerned: number[] }) =>
  measured.kerned.map((advance, index) => advance - measured.own[index]!);

/**
 * The operators that set `text` starting at `at`. pdf-lib's own `drawText`
 * places glyphs by their widths alone, so the kerning is written out here.
 */
function showText(
  { font, key }: { font: PDFFont; key: PDFName },
  text: string,
  at: { x: number; baseline: number; size: number; color: Colour },
  kerning: number[],
): PDFOperator[] {
  const chars = [...text];
  const parts: string[] = [];
  let glyphs = '';
  chars.forEach((char, index) => {
    glyphs += font.encodeText(char).asString();
    const kern = kerning[index] ?? 0;
    if (kern !== 0 && index < chars.length - 1) {
      // A positive number moves the next glyph left, in thousandths of an em.
      parts.push(`<${glyphs}>`, (-kern * 1000).toFixed(3));
      glyphs = '';
    }
  });
  parts.push(`<${glyphs}>`);
  return [
    beginText(),
    setFillingRgbColor(...at.color),
    setFontAndSize(key, at.size),
    setTextMatrix(1, 0, 0, 1, at.x, at.baseline),
    PDFOperator.of(PDFOperatorNames.ShowTextAdjusted, [`[${parts.join(' ')}]`]),
    endText(),
  ];
}
