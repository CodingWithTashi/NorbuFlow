import { type CalendarDate, compareDates, dateInMonth, todayIn } from '../../core/calendar-date';
import type { Caller } from '../../core/caller';
import { AppError } from '../../core/errors';
import type { FileStore } from '../../core/file-store';
import { type CardRenderer, type CardTemple, prepareCardPhoto } from '../cards';
import type { TempleAccess } from '../temples';
import type { MembershipTerm, Role, Temple } from '../temples/temple';
import type { FiledMember, Member, MemberNumber, MemberRepository, NumberTaken } from './member';

/** The roles whose Home screen in the app has "Add a Member". */
const mayAddMembers: Role[] = ['admin', 'frontDesk'];

/** Everyone who works at the temple's desk or in its office. */
const mayViewMembers: Role[] = ['admin', 'geshe', 'accountant', 'frontDesk', 'coordinator'];

// How long a link to a member's photo works. The app keeps the photo once it
// has it, so this only has to outlast a tablet left open at the desk.
const photoLinkSeconds = 7 * 24 * 60 * 60;

/** What every request about one member carries, tidied by `members.input.ts`. */
interface MemberDetails {
  /** Chosen by the app, so that asking twice does the work once. */
  id: string;
  name: string;
  /** Empty or left out when the member has none. */
  phone?: string;
  email?: string;
  templeId?: string;
}

export interface NewMemberRequest extends MemberDetails {
  /** The image as the app sent it. */
  photo: Uint8Array;
  /** The digits of a number typed by hand. Left out, they get the next one. */
  number?: string;
  /** Whether to give them a number that someone already holds. */
  replace?: boolean;
}

export interface PreviewCardRequest {
  /** Whose card it is. Left out, it is a new member's. */
  memberId?: string;
  name: string;
  /** Left out for a member on file, their photo is the one they have. */
  photo?: Uint8Array;
  number?: string;
  templeId?: string;
  /** A new member's last day, from a card made before NorbuFlow. Left out, one bought today. */
  validUntil?: CalendarDate;
}

export interface UpdateMemberRequest extends MemberDetails {
  memberId: string;
  /** Left out, they keep the photo they have. */
  photo?: Uint8Array;
  /** The digits of a new number. Left out, they keep the one they have. */
  number?: string;
}

/** When a membership began, when it was last bought or renewed, and its last day. */
export interface MembershipDates {
  joinedOn: CalendarDate;
  renewedOn: CalendarDate;
  expiresOn: CalendarDate;
}

/** A member as saved, with their print-ready card: front, then back. */
export interface IssuedCard {
  member: Member;
  pdf: Uint8Array;
}

/** A card as it would print, and the number on it. Nothing is saved. */
export interface CardPreview {
  number: MemberNumber;
  pdf: Uint8Array;
}

/** Membership rules. Knows nothing about HTTP, Firebase or SQL. */
export class MemberService {
  constructor(
    private readonly access: TempleAccess,
    private readonly members: MemberRepository,
    private readonly files: FileStore,
    private readonly cardRenderer: (temple: CardTemple, files: FileStore) => Promise<CardRenderer>,
    private readonly now: () => Date,
  ) {}

  /** The temple's members, the newest first. */
  async list(caller: Caller, templeId?: string): Promise<Member[]> {
    const temple = await this.access.templeFor(caller, templeId, mayViewMembers);
    return this.members.list(temple.id);
  }

  /** A week-long link to the photo of a member this service handed out. */
  photoUrl(member: Member): Promise<string | null> {
    return this.files.urlFor(member.photoKey, photoLinkSeconds);
  }

  /** A member and the card they were last issued. */
  async card(
    caller: Caller,
    request: { memberId: string; templeId?: string },
  ): Promise<IssuedCard> {
    const temple = await this.access.templeFor(caller, request.templeId, mayViewMembers);
    return this.withCard(await this.filed(temple, request.memberId));
  }

  /**
   * Draws the card a request would make, with the number it would carry:
   * the one typed, the member's own, or the temple's next.
   */
  async preview(caller: Caller, request: PreviewCardRequest): Promise<CardPreview> {
    const temple = await this.access.templeFor(caller, request.templeId, mayAddMembers);
    const { renderer, name } = await this.printable(temple, request.name);

    let photo: Uint8Array;
    let validUntil: CalendarDate;
    let digits = request.number;
    if (request.memberId) {
      const filed = await this.filed(temple, request.memberId);
      photo = request.photo
        ? await cardPhoto(renderer, request.photo)
        : await this.files.get(filed.member.photoKey);
      validUntil = filed.member.expiresOn;
      digits ??= filed.digits;
    } else {
      if (!request.photo) throw AppError.invalid({ photo: 'photoRequired' });
      photo = await cardPhoto(renderer, request.photo);
      validUntil =
        request.validUntil ??
        membershipEnd(temple.membershipTerm, todayIn(temple.timeZone, this.now()));
    }

    const number = await this.members.numberFor(temple.id, digits);
    const pdf = await renderer.render({ name, number: number.label, validUntil, photo });
    return { number, pdf };
  }

  /**
   * Adds a member and prints their card; the membership starts today. A
   * typed number someone holds adds nothing unless `replace`.
   */
  create(caller: Caller, request: NewMemberRequest): Promise<IssuedCard | NumberTaken> {
    return this.add(caller, request);
  }

  /**
   * Adds a member who already holds a card made before NorbuFlow, with that
   * card's number and dates. A number someone holds adds nothing.
   */
  addExisting(
    caller: Caller,
    request: NewMemberRequest & { number: string },
    dates: MembershipDates,
  ): Promise<IssuedCard | NumberTaken> {
    return this.add(caller, { ...request, replace: false }, dates);
  }

  private async add(
    caller: Caller,
    request: NewMemberRequest,
    dates?: MembershipDates,
  ): Promise<IssuedCard | NumberTaken> {
    const temple = await this.access.templeFor(caller, request.templeId, mayAddMembers);

    // Everything that could stop the card printing is checked before a
    // membership number is taken.
    const { renderer, name } = await this.printable(temple, request.name);
    const photo = await cardPhoto(renderer, request.photo);
    const today = todayIn(temple.timeZone, this.now());
    const { joinedOn, renewedOn, expiresOn } = dates ?? {
      joinedOn: today,
      renewedOn: today,
      expiresOn: membershipEnd(temple.membershipTerm, today),
    };

    const saved = await this.members.save(
      {
        id: request.id,
        templeId: temple.id,
        name,
        email: request.email || null,
        phone: request.phone || null,
        joinedOn,
        renewedOn,
        expiresOn,
        createdBy: caller.uid,
      },
      { digits: request.number, replace: request.replace ?? false },
      async (number, memberId) => {
        const { photoKey, pdfKey } = cardFiles(temple.id, memberId, request.id);
        await this.files.put(photoKey, photo, 'image/jpeg');
        const pdf = await renderer.render({ name, number, validUntil: expiresOn, photo });
        await this.files.put(pdfKey, pdf, 'application/pdf');
        return { id: request.id, template: temple.cardTemplate, photoKey, pdfKey, pdf };
      },
    );
    if ('taken' in saved) return saved;
    if ('issued' in saved) return this.withCard(saved.issued);
    return { member: saved.member, pdf: saved.card.pdf };
  }

  /**
   * Changes a member's details. Their card is printed again only if what is
   * on it changed: the name, the photo or the number.
   */
  async update(caller: Caller, request: UpdateMemberRequest): Promise<IssuedCard | NumberTaken> {
    const temple = await this.access.templeFor(caller, request.templeId, mayAddMembers);
    const { renderer, name } = await this.printable(temple, request.name);
    const photo = request.photo && (await cardPhoto(renderer, request.photo));

    const changed = await this.members.change(
      {
        cardId: request.id,
        templeId: temple.id,
        memberId: request.memberId,
        name,
        email: request.email || null,
        phone: request.phone || null,
        number: request.number,
        changedBy: caller.uid,
      },
      async ({ member }, number) => {
        if (!photo && name === member.name && number === member.number) return undefined;

        const { photoKey, pdfKey } = cardFiles(temple.id, member.id, request.id);
        if (photo) await this.files.put(photoKey, photo, 'image/jpeg');
        const pdf = await renderer.render({
          name,
          number,
          validUntil: member.expiresOn,
          photo: photo ?? (await this.files.get(member.photoKey)),
        });
        await this.files.put(pdfKey, pdf, 'application/pdf');
        return {
          id: request.id,
          template: temple.cardTemplate,
          photoKey: photo ? photoKey : member.photoKey,
          pdfKey,
          pdf,
        };
      },
    );
    if (!changed) throw noSuchMember(temple, request.memberId);
    if ('taken' in changed) return changed;
    if ('issued' in changed) return this.withCard(changed.issued);
    return {
      member: changed.member,
      pdf: changed.card?.pdf ?? (await this.files.get(changed.pdfKey)),
    };
  }

  private async withCard(filed: FiledMember): Promise<IssuedCard> {
    return { member: filed.member, pdf: await this.files.get(filed.pdfKey) };
  }

  private async filed(temple: Temple, memberId: string): Promise<FiledMember> {
    const filed = await this.members.find(temple.id, memberId);
    if (!filed) throw noSuchMember(temple, memberId);
    return filed;
  }

  /** The temple's card, and `name` as it prints on it. Refuses a name it cannot print. */
  private async printable(
    temple: Temple,
    typed: string,
  ): Promise<{ renderer: CardRenderer; name: string }> {
    const renderer = await this.cardRenderer(temple, this.files);
    const name = typed.replace(/\s+/g, ' ');
    const problem = renderer.nameProblem(name);
    if (problem === 'unsupported') throw AppError.invalid({ name: 'memberNameUnsupported' });
    if (problem === 'tooLong') throw AppError.invalid({ name: 'memberNameTooLong' });
    return { renderer, name };
  }
}

function noSuchMember(temple: Temple, memberId: string): AppError {
  return AppError.notFound(`${temple.id} has no member with the id "${memberId}".`);
}

/** Where a card's photo and its PDF are kept: side by side, under the member. */
function cardFiles(templeId: string, memberId: string, cardId: string) {
  const card = `temples/${templeId}/members/${memberId}/cards/${cardId}`;
  return { photoKey: `${card}.jpg`, pdfKey: `${card}.pdf` };
}

async function cardPhoto(renderer: CardRenderer, image: Uint8Array): Promise<Uint8Array> {
  const photo = await prepareCardPhoto(image, renderer.photoPixels);
  if (!photo) throw AppError.invalid({ photo: 'photoUnreadable' });
  return photo;
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
