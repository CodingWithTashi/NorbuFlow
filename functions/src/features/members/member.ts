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
  joinedOn: CalendarDate;
  /** When the current membership was bought or last renewed. */
  renewedOn: CalendarDate;
  /** The last day of the current membership. */
  expiresOn: CalendarDate;
}

export interface NewMember {
  /** Chosen by the app, so that asking twice adds one member. */
  id: string;
  templeId: string;
  name: string;
  email: string | null;
  phone: string | null;
  /** Where their photo is in the file store. */
  photoKey: string;
  joinedOn: CalendarDate;
  renewedOn: CalendarDate;
  expiresOn: CalendarDate;
  /** The Firebase uid of whoever is adding them. */
  createdBy: string;
}

/** The record of a card that was printed: which design, and where its files are. */
export interface IssuedCardRecord {
  id: string;
  template: string;
  photoKey: string;
  pdfKey: string;
}

export interface MemberRepository {
  /** A temple's member by id, and where the card they were last issued is filed. */
  find(templeId: string, id: string): Promise<{ member: Member; pdfKey: string } | undefined>;

  /**
   * Saves a new member under the temple's next number, with the card that
   * `issueCard` makes for it. If that fails, nothing is saved or used up.
   */
  create<Card extends IssuedCardRecord>(
    member: NewMember,
    issueCard: (number: string) => Promise<Card>,
  ): Promise<{ member: Member; card: Card }>;
}
