/**
 * Turns whatever the app sent into the photo a card prints: upright, cropped
 * to cover `size`, and a JPEG. `undefined` if it is not a picture.
 */
export async function prepareCardPhoto(
  image: Uint8Array,
  size: { width: number; height: number },
): Promise<Uint8Array | undefined> {
  // Loaded on first use: only a function that takes a photo needs it.
  const { default: sharp } = await import('sharp');
  try {
    return await sharp(image)
      .rotate() // Phones store portrait shots sideways and say so in the metadata.
      .resize(size.width, size.height, { fit: 'cover' })
      .flatten({ background: '#ffffff' })
      .jpeg({ quality: 90 })
      .toBuffer();
  } catch {
    return undefined;
  }
}
