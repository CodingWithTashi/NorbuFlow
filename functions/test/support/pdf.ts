import { createCanvas } from '@napi-rs/canvas';
import { getDocument } from 'pdfjs-dist/legacy/build/pdf.mjs';

export interface PlacedText {
  text: string;
  /** Left end of the baseline, in points. */
  x: number;
  y: number;
  size: number;
  width: number;
}

// pdf.js takes ownership of the bytes it is given, so it gets a copy.
const open = (pdf: Uint8Array) => getDocument({ data: new Uint8Array(pdf), verbosity: 0 }).promise;

const pageOf = async (pdf: Uint8Array, pageNumber: number) => (await open(pdf)).getPage(pageNumber);

export async function pageCount(pdf: Uint8Array): Promise<number> {
  return (await open(pdf)).numPages;
}

/** A page's size in points. */
export async function pageSize(pdf: Uint8Array, pageNumber: number) {
  const [left, bottom, right, top] = (await pageOf(pdf, pageNumber)).view as number[];
  return { width: right! - left!, height: top! - bottom! };
}

/** Where each run of text sits on a page, as a PDF viewer would place it. */
export async function textOn(pdf: Uint8Array, pageNumber: number): Promise<PlacedText[]> {
  const content = await (await pageOf(pdf, pageNumber)).getTextContent();
  const round = (value: number) => Math.round(value * 1000) / 1000;
  return content.items.flatMap((item) =>
    'str' in item && item.str.trim()
      ? [
          {
            text: item.str,
            x: round(item.transform[4]),
            y: round(item.transform[5]),
            size: round(item.transform[0]),
            width: round(item.width),
          },
        ]
      : [],
  );
}

/** Draws a page and returns a function giving the colour at a point, in points from the bottom-left. */
export async function colourAt(pdf: Uint8Array, pageNumber: number) {
  const page = await pageOf(pdf, pageNumber);
  const scale = 4;
  const viewport = page.getViewport({ scale });
  const canvas = createCanvas(Math.ceil(viewport.width), Math.ceil(viewport.height));
  const context = canvas.getContext('2d');
  await page.render({
    canvas: canvas as unknown as HTMLCanvasElement,
    canvasContext: context as unknown as CanvasRenderingContext2D,
    viewport,
  }).promise;
  const [left, bottom] = page.view as [number, number, number, number];
  return (x: number, y: number): [number, number, number] => {
    const pixel = context.getImageData(
      Math.round((x - left) * scale),
      Math.round(canvas.height - (y - bottom) * scale),
      1,
      1,
    ).data;
    return [pixel[0]!, pixel[1]!, pixel[2]!];
  };
}
