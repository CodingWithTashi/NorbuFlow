import type { CalendarDate } from '../../core/calendar-date';

export type FontKey = 'regular' | 'bold';

export interface TextStyle {
  font: FontKey;
  /** In points. */
  size: number;
  /** Red, green, blue, each 0–1. */
  color: readonly [number, number, number];
  /** Extra space after every character, in ems. */
  letterSpacing: number;
}

/** A column that text is centred in. */
export interface TextColumn {
  x: number;
  width: number;
  /** The grid a centred line's start is rounded down to, as design tools do. */
  snap: number;
}

/**
 * A temple's membership card: the designer's exported artwork, and where a
 * member's details go on it. Positions are in PDF points; text sits on baselines.
 */
export interface CardTemplate {
  /** One-page PDFs. */
  front: Uint8Array;
  back: Uint8Array;
  fonts: Record<FontKey, Uint8Array>;

  /** The photo covers this box and is clipped to its rounded corners. */
  photo: { x: number; y: number; width: number; height: number; radius: number };

  /** Centred, wrapping onto further lines when wider than its column. */
  name: TextStyle &
    TextColumn & {
      baseline: number;
      /** Distance between the baselines of two lines of the name. */
      lineHeight: number;
      /** More lines than this would run into the membership number. */
      maxLines: number;
    };

  /** Centred under the name, moving down with each extra line of it. */
  validity: TextStyle &
    TextColumn & {
      /** Distance from the last baseline of the name to this one. */
      below: number;
      text: (validUntil: CalendarDate) => string;
    };

  numberLabel: TextStyle & Anchor & { text: string };
  number: TextStyle & Anchor;
}

/** Where a line of text sits: starting at `x`, or centred in `column`. */
export type Anchor = { baseline: number } & ({ x: number } | { column: TextColumn });
