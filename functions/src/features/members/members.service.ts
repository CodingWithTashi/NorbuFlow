import { randomUUID } from 'node:crypto';

import { type CalendarDate, compareDates, dateInMonth, todayIn } from '../../core/calendar-date';
import type { Caller } from '../../core/caller';
import { AppError } from '../../core/errors';
import type { FileStore } from '../../core/file-store';
import { type CardRenderer, prepareCardPhoto } from '../cards';
import type { TempleAccess } from '../temples';
import type { MembershipTerm, Role } from '../temples/temple';
import type { Member, MemberRepository } from './member';

/** The roles whose Home screen in the app has "Add a Member". */
const mayAddMembers: Role[] = ['admin', 'frontDesk'];

/** A new member's details, as `members.input.ts` leaves them: tidied and within limits. */
export interface NewMemberRequest {
  /** Chosen by the app, so that asking twice adds one member. */
  id: string;
  name: string;
  phone: string;
  /** Empty when the member has none. */
  email?: string;
  /** The image as the app sent it. */
  photo: Uint8Array;
  templeId?: string;
}

export interface NewMemberResult {
  member: Member;
  /** Their print-ready card: front, then back. */
  pdf: Uint8Array;
}

/** Membership rules. Knows nothing about HTTP, Firebase or SQL. */
export class MemberService {
  constructor(
    private readonly access: TempleAccess,
    private readonly members: MemberRepository,
    private readonly files: FileStore,
    private readonly cardRenderer: (template: string) => Promise<CardRenderer>,
    private readonly now: () => Date,
  ) {}

  /**
   * Adds a member and prints their card: gives them the temple's next
   * membership number and a membership that starts today.
   */
  async create(caller: Caller, request: NewMemberRequest): Promise<NewMemberResult> {
    const temple = await this.access.templeFor(caller, request.templeId, mayAddMembers);

    // Asked again because the answer was lost: the same member and card, not a second.
    const existing = await this.members.find(temple.id, request.id);
    if (existing) return { member: existing.member, pdf: await this.files.get(existing.pdfKey) };

    // Everything that could stop the card printing is checked before a
    // membership number is taken.
    const renderer = await this.cardRenderer(temple.cardTemplate);
    const name = request.name.replace(/\s+/g, ' ');
    const problem = renderer.nameProblem(name);
    if (problem === 'unsupported') throw AppError.invalid({ name: 'memberNameUnsupported' });
    if (problem === 'tooLong') throw AppError.invalid({ name: 'memberNameTooLong' });
    const photo = await prepareCardPhoto(request.photo, renderer.photoPixels);
    if (!photo) throw AppError.invalid({ photo: 'photoUnreadable' });

    const today = todayIn(temple.timeZone, this.now());
    const expiresOn = membershipEnd(temple.membershipTerm, today);
    const folder = `temples/${temple.id}/members/${request.id}`;
    const photoKey = `${folder}/photo.jpg`;
    await this.files.put(photoKey, photo, 'image/jpeg');

    const { member, card } = await this.members.create(
      {
        id: request.id,
        templeId: temple.id,
        name,
        email: request.email || null,
        phone: request.phone,
        photoKey,
        joinedOn: today,
        renewedOn: today,
        expiresOn,
        createdBy: caller.uid,
      },
      async (number) => {
        const cardId = randomUUID();
        const pdfKey = `${folder}/cards/${cardId}.pdf`;
        const pdf = await renderer.render({ name, number, validUntil: expiresOn, photo });
        await this.files.put(pdfKey, pdf, 'application/pdf');
        return { id: cardId, template: temple.cardTemplate, photoKey, pdfKey, pdf };
      },
    );
    return { member, pdf: card.pdf };
  }
}

/** The last day of a membership bought or renewed `today`. */
export function membershipEnd(term: MembershipTerm, today: CalendarDate): CalendarDate {
  if (term.kind === 'rolling') {
    // 31 January plus a month is the last day of February, not 3 March.
    const months = today.year * 12 + (today.month - 1) + term.months;
    return dateInMonth(Math.floor(months / 12), (months % 12) + 1, today.day);
  }
  // The temple's next year end. Bought on the year end itself, it runs a full year.
  const yearEnd = (year: number) => dateInMonth(year, term.month, term.day);
  const thisYear = yearEnd(today.year);
  return compareDates(thisYear, today) > 0 ? thisYear : yearEnd(today.year + 1);
}
