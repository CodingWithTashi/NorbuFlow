import { PDFDocument, type PDFPage, rgb } from 'pdf-lib';

import { readAsset } from '../../../core/assets';
import {
  drawCentred,
  embedFonts,
  type Fonts,
  type NameProblem,
  textProblem,
  wrap,
} from '../card-renderer';
import type { CardTemplate, FontKey, TextColumn, TextStyle } from '../card-template';
import { monthNames } from '../month-names';

type Colour = readonly [number, number, number];

/** What the standard card shows of the temple it belongs to. */
interface StandardCardTemple {
  name: string;
  /** A PNG. Left out, the header carries the name alone. */
  logo?: Uint8Array;
}

// The same size as a designed card, so both print on the same stock.
const page = { width: 159.75, height: 252 };
const centre = page.width / 2;

const maroon: Colour = [0.478, 0.122, 0.169];
const gold: Colour = [0.788, 0.635, 0.153];
const ink: Colour = [0.169, 0.102, 0.09];
const muted: Colour = [0.42, 0.36, 0.34];
const parchment: Colour = [0.984, 0.965, 0.925];
const white: Colour = [1, 1, 1];

const column: TextColumn = { x: 10, width: page.width - 20, snap: 0.01 };

const text = (font: FontKey, size: number, color: Colour, letterSpacing = 0): TextStyle => ({
  font,
  size,
  color,
  letterSpacing,
});

/** The temple's name, in the header and on the back: one or two lines. */
const templeName = { ...column, ...text('bold', 8, white), lineHeight: 9.6, maxLines: 2 };

const header = { bottom: 182, logoCentre: 229, logoRadius: 17, logoSize: 24 };
const footerTop = 36;
// The back: a strip with the card's title, the logo, then who to return it to.
const back = {
  stripBottom: 232,
  title: 240,
  logoCentre: 186,
  logoSize: 44,
  wording: 144,
  wordingAlone: 156,
  nameBelow: 13,
};

// The height of Open Sans capitals, as a fraction of the type size.
const openSansCapHeight = 0.714;

// Read once: both sides of every standard card use the same two files.
let fontFiles: Record<FontKey, Uint8Array> | undefined;
const fonts = () =>
  (fontFiles ??= {
    regular: readAsset('fonts', 'OpenSans-Regular.ttf'),
    bold: readAsset('fonts', 'OpenSans-Bold.ttf'),
  });

/**
 * The card a temple prints until it has a design of its own: NorbuFlow's
 * layout, carrying the temple's name and logo.
 */
export async function standardCard(temple: StandardCardTemple): Promise<CardTemplate> {
  const [front, back] = await Promise.all([frontArtwork(temple), backArtwork(temple)]);
  return {
    front,
    back,
    fonts: fonts(),
    // The shape of the photo box every card has, so the app crops one way.
    photo: { x: 40.151, y: 84, width: 79.44738, height: 90.434528, radius: 3.744516 },
    name: { ...column, ...text('bold', 10, ink), baseline: 67, lineHeight: 11, maxLines: 2 },
    validity: {
      ...column,
      ...text('regular', 6.5, muted),
      below: 9.5,
      text: ({ year, month, day }) => `Valid until ${day} ${monthNames[month - 1]} ${year}`,
    },
    numberLabel: {
      ...text('regular', 5, muted),
      column,
      baseline: 24.5,
      text: 'Membership number',
    },
    number: { ...text('bold', 11, ink), column, baseline: 11 },
  };
}

/** Why the standard card cannot carry a temple called `name`, if it cannot. */
export async function standardNameProblem(name: string): Promise<NameProblem | undefined> {
  const scratch = await PDFDocument.create();
  return textProblem(await embedFonts(scratch, { fonts: fonts() }), templeName, name);
}

async function frontArtwork(temple: StandardCardTemple): Promise<Uint8Array> {
  const { pdf, sheet, embedded } = await blankSide();
  fill(sheet, 0, header.bottom, page.width, page.height - header.bottom, maroon);
  fill(sheet, 0, header.bottom - 1.5, page.width, 1.5, gold);
  footer(sheet);

  const lines = wrap(embedded, templeName, temple.name);
  if (temple.logo) {
    const logo = await pdf.embedPng(temple.logo);
    const { width, height } = logo.scaleToFit(header.logoSize, header.logoSize);
    // A white disc, so a logo of any colour shows on the maroon.
    sheet.drawCircle({
      x: centre,
      y: header.logoCentre,
      size: header.logoRadius,
      color: rgb(...white),
    });
    sheet.drawImage(logo, {
      x: centre - width / 2,
      y: header.logoCentre - height / 2,
      width,
      height,
    });
  }
  // Centred in the space under the logo; with no logo, in the whole header.
  const top = temple.logo ? header.logoCentre - header.logoRadius : page.height;
  const middle = (top + header.bottom) / 2;
  const capHeight = templeName.size * openSansCapHeight;
  const block = capHeight + (lines.length - 1) * templeName.lineHeight;
  lines.forEach((line, index) => {
    const baseline = middle + block / 2 - capHeight - index * templeName.lineHeight;
    drawCentred(sheet, embedded, templeName, line, baseline);
  });
  return pdf.save();
}

async function backArtwork(temple: StandardCardTemple): Promise<Uint8Array> {
  const { pdf, sheet, embedded } = await blankSide();
  fill(sheet, 0, back.stripBottom, page.width, page.height - back.stripBottom, maroon);
  fill(sheet, 0, back.stripBottom - 1.5, page.width, 1.5, gold);
  footer(sheet);
  drawCentred(
    sheet,
    embedded,
    { ...column, ...text('bold', 5.5, white, 0.12) },
    'MEMBERSHIP CARD',
    back.title,
  );

  if (temple.logo) {
    const logo = await pdf.embedPng(temple.logo);
    const { width, height } = logo.scaleToFit(back.logoSize, back.logoSize);
    const y = back.logoCentre - height / 2;
    sheet.drawImage(logo, { x: centre - width / 2, y, width, height });
  }
  // With no logo above it, the wording moves up to the middle of the card.
  const wording = temple.logo ? back.wording : back.wordingAlone;
  drawCentred(
    sheet,
    embedded,
    { ...column, ...text('regular', 6, muted) },
    'If found, please return this card to',
    wording,
  );
  wrap(embedded, templeName, temple.name).forEach((line, index) => {
    const baseline = wording - back.nameBelow - index * templeName.lineHeight;
    drawCentred(sheet, embedded, { ...templeName, color: ink }, line, baseline);
  });
  return pdf.save();
}

async function blankSide(): Promise<{ pdf: PDFDocument; sheet: PDFPage; embedded: Fonts }> {
  const pdf = await PDFDocument.create();
  const sheet = pdf.addPage([page.width, page.height]);
  fill(sheet, 0, 0, page.width, page.height, white);
  return { pdf, sheet, embedded: await embedFonts(pdf, { fonts: fonts() }) };
}

function footer(sheet: PDFPage): void {
  fill(sheet, 0, 0, page.width, footerTop, parchment);
  fill(sheet, 0, footerTop, page.width, 0.75, gold);
}

function fill(sheet: PDFPage, x: number, y: number, width: number, height: number, colour: Colour) {
  sheet.drawRectangle({ x, y, width, height, color: rgb(...colour) });
}
