import type { CalendarDate } from '../../core/calendar-date';
import type { BodyBox, BodyFace } from './text-layout';

/** The body's faces, and the face of the number and the date. */
export type LetterFace = BodyFace | 'display';

/** Red, green, blue, each 0–1. */
export type Colour = readonly [number, number, number];

/** One line set in the display face, sitting on `baseline`. */
interface DisplayLine {
  size: number;
  color: Colour;
  baseline: number;
}

/**
 * A temple's support letter: its letterhead, and where a letter's own words
 * go on it. Positions are in PDF points; text sits on baselines.
 */
export interface LetterTemplate {
  /** A one-page PDF with everything that is the same on every letter. */
  page: Uint8Array;
  fonts: Record<LetterFace, Uint8Array>;

  /** The letter's number, ending at `right`. */
  number: DisplayLine & { right: number; text: (digits: string) => string };

  /** The last day the letter holds, starting at `x`. */
  validUntil: DisplayLine & { x: number; text: (date: CalendarDate) => string };

  body: BodyBox & {
    color: Colour;
    /** Whether the design kerns this pair of characters. Its tool leaves some out. */
    kerned: (first: string, second: string) => boolean;
  };
}
