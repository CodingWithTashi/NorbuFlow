import { readAsset } from '../../../core/assets';
import type { CardTemplate } from '../card-template';
import { monthNames } from '../month-names';

const artwork = 'drepung-loseling-canada';
const ink = [0.0353, 0.0588, 0.0627] as const;
const letterSpacing = 0.001;

// Canva lays the name and validity out in one text box, in its own pixels.
// These convert that box to points.
const pixel = 0.748903032;
const column = { x: 29.11285584, width: 138.875 * pixel, snap: pixel / 64 };

/**
 * Drepung Loseling Canada's card. Artwork, font (Open Sans 1.10) and every
 * number below come from the temple's Canva file "ID Card master".
 */
export function drepungLoselingCanada(): CardTemplate {
  return {
    front: readAsset('cards', artwork, 'front.pdf'),
    back: readAsset('cards', artwork, 'back.pdf'),
    fonts: {
      regular: readAsset('fonts', 'OpenSans-Regular.ttf'),
      bold: readAsset('fonts', 'OpenSans-Bold.ttf'),
    },
    photo: { x: 40.392835, y: 87.702995, width: 79.44738, height: 90.434528, radius: 3.744516 },
    name: {
      ...column,
      font: 'bold',
      size: 12 * pixel,
      color: ink,
      letterSpacing,
      baseline: 69.219316,
      lineHeight: 12 * pixel,
      maxLines: 2,
    },
    validity: {
      ...column,
      font: 'regular',
      size: 8 * pixel,
      color: ink,
      letterSpacing,
      below: 10 * pixel,
      text: ({ year, month, day }) =>
        `Valid: ${year}-${monthNames[month - 1]}-${String(day).padStart(2, '0')}`,
    },
    numberLabel: {
      font: 'regular',
      size: 4.99268677,
      color: ink,
      letterSpacing,
      x: 64.4026685,
      baseline: 39.6651,
      text: 'Membership number',
    },
    number: {
      font: 'bold',
      size: 9.98537354,
      color: ink,
      letterSpacing,
      x: 64.4026685,
      baseline: 28.847613,
    },
  };
}
