import type { CalendarDate } from '../../core/calendar-date';

/** A stretch of one line's text, set one way. */
export interface LetterRun {
  text: string;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
}

/**
 * One line as it was written. With no text it is an empty line; before the
 * first words, empty lines set how far down the page the letter starts.
 */
export interface LetterLine {
  /** Whether it is an item of a list. */
  bullet?: boolean;
  runs: LetterRun[];
}

/** What a letter says, line by line. A line too wide for the page wraps. */
export type LetterBody = LetterLine[];

/** A support letter that was issued. It never changes. */
export interface Letter {
  id: string;
  templeId: string;
  /** The digits printed after "No." */
  number: string;
  /** Who it is for. */
  name: string;
  /** The member it is for, when it is for one. */
  memberId: string | null;
  validUntil: CalendarDate;
  issuedOn: CalendarDate;
}

/** A letter on file: what it says, and where its PDF is kept. */
export interface FiledLetter {
  letter: Letter;
  body: LetterBody;
  pdfKey: string;
}

export interface NewLetter {
  /** Chosen by the app, so that asking twice issues one letter. */
  id: string;
  templeId: string;
  name: string;
  memberId: string | null;
  validUntil: CalendarDate;
  issuedOn: CalendarDate;
  body: LetterBody;
  template: string;
  /** The Firebase uid of whoever is issuing it. */
  issuedBy: string;
}

/** The number asked for is already on this letter. */
export interface NumberTaken {
  taken: Letter;
}

/** The request was made before: this is what it made then. */
export interface AlreadyIssued {
  issued: FiledLetter;
}

export interface LetterRepository {
  /** A temple's letters, the newest first. */
  list(templeId: string): Promise<Letter[]>;

  find(templeId: string, id: string): Promise<FiledLetter | undefined>;

  /** Whether the temple has a member with this id: who a letter may be linked to. */
  isMember(templeId: string, memberId: string): Promise<boolean>;

  /** The number a letter would carry: `digits` if given, else the temple's next free one. */
  numberFor(templeId: string, digits?: string): Promise<string>;

  /**
   * Saves a letter under the number typed by hand, or the temple's next.
   * `file` draws and stores its PDF once the number is known.
   */
  save(
    letter: NewLetter,
    digits: string | undefined,
    file: (number: string) => Promise<{ pdfKey: string; pdf: Uint8Array }>,
  ): Promise<{ letter: Letter; pdf: Uint8Array } | NumberTaken | AlreadyIssued>;
}
