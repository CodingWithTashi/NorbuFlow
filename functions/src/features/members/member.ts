import type { CalendarDate } from '../../core/calendar-date';

/** A member as they stand today. */
export interface Member {
  id: string;
  templeId: string;
  /** As the temple writes it, e.g. `194915308` or `JC-0142`. */
  number: string;
  name: string;
  email: string | null;
  phone: string | null;
  /** Where their photo is in the file store. */
  photoKey: string;
  /** The card they hold now. It changes only when a new one is printed. */
  cardId: string | null;
  joinedOn: CalendarDate;
  /** When the current membership was bought or last renewed. */
  renewedOn: CalendarDate;
  /** The last day of the current membership. */
  expiresOn: CalendarDate;
}

/** A membership number: the digits that are counted, and how the temple writes them. */
export interface MemberNumber {
  digits: string;
  label: string;
}

/** How a temple writes its numbers: prefix `JC-` and 4 digits make 142 `JC-0142`. */
export interface NumberFormat {
  prefix: string;
  minDigits: number;
}

export function writeNumber(format: NumberFormat, digits: string): string {
  return format.prefix + digits.padStart(format.minDigits, '0');
}

/** A member on file: who they are, and where the card they hold is kept. */
export interface FiledMember {
  member: Member;
  /** Their number as it is counted. */
  digits: string;
  pdfKey: string;
}

export interface NewMember {
  /** Chosen by the app: the card's id, and the member's unless they replace someone. */
  id: string;
  templeId: string;
  name: string;
  email: string | null;
  phone: string | null;
  joinedOn: CalendarDate;
  renewedOn: CalendarDate;
  expiresOn: CalendarDate;
  /** The Firebase uid of whoever is adding them. */
  createdBy: string;
}

/** New details for a member who is already on file. */
export interface MemberChange {
  /** Chosen by the app: the id of the card this change prints, if it prints one. */
  cardId: string;
  templeId: string;
  memberId: string;
  name: string;
  email: string | null;
  phone: string | null;
  /** The digits of a new number. Left out, they keep the one they have. */
  number?: string;
  /** The Firebase uid of whoever is changing them. */
  changedBy: string;
}

/** The record of a card that was printed: which design, and where its files are. */
export interface IssuedCardRecord {
  /** Chosen by the app, so that asking twice issues one card. */
  id: string;
  template: string;
  photoKey: string;
  pdfKey: string;
}

/** The number asked for already belongs to this member. */
export interface NumberTaken {
  taken: Member;
}

/** The request was made before: this is what it made then. */
export interface AlreadyIssued {
  issued: FiledMember;
}

export interface MemberRepository {
  /** A temple's members, the newest first. */
  list(templeId: string): Promise<Member[]>;

  find(templeId: string, id: string): Promise<FiledMember | undefined>;

  /** `digits` as the temple writes them. Left out: the number its next new member gets. */
  numberFor(templeId: string, digits?: string): Promise<MemberNumber>;

  /**
   * Saves a member and the card `issueCard` makes, or neither row. `digits`
   * someone holds are `taken` unless `replace`: their record is overwritten.
   */
  save<Card extends IssuedCardRecord>(
    member: NewMember,
    number: { digits?: string; replace: boolean },
    issueCard: (number: string, memberId: string) => Promise<Card>,
  ): Promise<{ member: Member; card: Card } | NumberTaken | AlreadyIssued>;

  /**
   * Changes a member, with the card `reissue` makes if any. `undefined` if
   * there is no such member; a number someone else holds changes nothing.
   */
  change<Card extends IssuedCardRecord>(
    change: MemberChange,
    reissue: (filed: FiledMember, number: string) => Promise<Card | undefined>,
  ): Promise<
    { member: Member; card?: Card; pdfKey: string } | NumberTaken | AlreadyIssued | undefined
  >;
}
