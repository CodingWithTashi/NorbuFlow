/** No screen or card shows a logo larger than this many pixels a side. */
const longestSide = 512;

/**
 * Turns an uploaded image into the logo that is kept: upright, no larger
 * than needed, and a PNG. `undefined` if it is not a picture.
 */
export async function prepareLogo(image: Uint8Array): Promise<Uint8Array | undefined> {
  // Loaded on first use: only a function that takes a picture needs it.
  const { default: sharp } = await import('sharp');
  try {
    return await sharp(image)
      .rotate()
      .resize(longestSide, longestSide, { fit: 'inside', withoutEnlargement: true })
      .png()
      .toBuffer();
  } catch {
    return undefined;
  }
}
