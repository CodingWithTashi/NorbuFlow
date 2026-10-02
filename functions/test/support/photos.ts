import sharp from 'sharp';

/** The one colour every test photo is, as red, green and blue. */
export const photoColour = [0x33, 0x66, 0xcc] as const;

/** A plain-coloured picture, standing in for a photo of a person. */
export function photo(width: number, height: number, format: 'jpeg' | 'png' = 'jpeg') {
  const [r, g, b] = photoColour;
  return sharp({ create: { width, height, channels: 3, background: { r, g, b } } })
    .toFormat(format)
    .toBuffer();
}
