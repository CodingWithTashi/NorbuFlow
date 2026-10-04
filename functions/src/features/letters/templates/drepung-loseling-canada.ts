import { readAsset } from '../../../core/assets';
import type { LetterTemplate } from '../letter-template';

const artwork = ['temples', 'drepung-loseling-canada', 'support-letter'];
const ink = [0x2c / 255, 0x2e / 255, 0x35 / 255] as const;
const red = [0xc2 / 255, 0x2a / 255, 0x1b / 255] as const;

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/**
 * Drepung Loseling Canada's letter, as its Illustrator file "Letter" has it:
 * Roboto 2.136 hinted. Crimson Pro stands in for Minion, which is not free.
 */
export function drepungLoselingCanada(): LetterTemplate {
  return {
    page: readAsset(...artwork, 'letter-master.pdf'),
    fonts: {
      regular: readAsset('fonts', 'Roboto-Regular.ttf'),
      bold: readAsset('fonts', 'Roboto-Bold.ttf'),
      italic: readAsset('fonts', 'Roboto-Italic.ttf'),
      boldItalic: readAsset('fonts', 'Roboto-BoldItalic.ttf'),
      display: readAsset('fonts', 'CrimsonPro-SemiBold.ttf'),
    },
    number: {
      size: 16,
      color: red,
      baseline: 702.792,
      right: 555.764,
      text: (digits) => `No. ${digits}`,
    },
    validUntil: {
      size: 14,
      color: ink,
      baseline: 701.642,
      x: 49.443,
      text: ({ year, month, day }) => `Valid Until ${months[month - 1]} ${day}, ${year}`,
    },
    body: {
      x: 49.7949,
      // The temple's letter fits a line of 491.9 and turns one of 494.6.
      width: 493.2,
      baseline: 646.2202,
      lineHeight: 17.0038,
      // One line is left clear above "Sincerely,".
      maxLines: 25,
      size: 11.6,
      listIndent: 14,
      color: ink,
      // The temple's own letters have no kerning onto an "e" or beside a "y".
      kerned: (first, second) => first !== 'y' && second !== 'y' && second !== 'e',
    },
  };
}
