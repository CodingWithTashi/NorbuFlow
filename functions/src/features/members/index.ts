import type { CallableOptions } from 'firebase-functions/v2/https';

import { toIsoDate } from '../../core/calendar-date';
import { defineCallable } from '../../core/callable';
import { lazy } from '../../core/lazy';
import { database, fileStore } from '../../runtime';
import { cardRenderer } from '../cards';
import { templeAccess } from '../temples';
import type { Member, NumberTaken } from './member';
import {
  listMembersInput,
  memberCardInput,
  newMemberInput,
  previewCardInput,
  updateMemberInput,
} from './members.input';
import { type IssuedCard, MemberService } from './members.service';
import { PostgresMemberRepository } from './postgres-member.repository';

const service = lazy(
  async () =>
    new MemberService(
      await templeAccess(),
      new PostgresMemberRepository(await database()),
      await fileStore(),
      cardRenderer,
      () => new Date(),
    ),
);

// Drawing a card needs room for the photo, the fonts and the PDF.
const drawsCards: CallableOptions = { memory: '1GiB', timeoutSeconds: 60 };

const bytes = (base64: string) => Buffer.from(base64, 'base64');
const base64 = (pdf: Uint8Array) => Buffer.from(pdf).toString('base64');
// A photo is left out when the member keeps the one they have.
const photoOf = (sent?: string) => (sent === undefined ? undefined : bytes(sent));

/** A member as the app shows them, with a link to their photo. */
const memberJson = async (members: MemberService, member: Member) => ({
  id: member.id,
  number: member.number,
  name: member.name,
  email: member.email,
  phone: member.phone,
  joinedOn: toIsoDate(member.joinedOn),
  renewedOn: toIsoDate(member.renewedOn),
  expiresOn: toIsoDate(member.expiresOn),
  // The card they hold, so the app can keep it and know when it is replaced.
  cardId: member.cardId,
  // The key names the photo for good; the link to it changes every time.
  photoKey: member.photoKey,
  photoUrl: await members.photoUrl(member),
});

/** A saved member with their card, or who holds the number that was asked for. */
const issuedJson = async (members: MemberService, result: IssuedCard | NumberTaken) =>
  'taken' in result
    ? { taken: { name: result.taken.name, number: result.taken.number } }
    : { member: await memberJson(members, result.member), card: { pdf: base64(result.pdf) } };

/** `members-list`: the temple's members, the newest first. */
export const list = defineCallable({
  input: listMembersInput,
  handler: async (caller, input) => {
    const members = await service();
    const listed = await members.list(caller, input?.templeId);
    return { members: await Promise.all(listed.map((member) => memberJson(members, member))) };
  },
});

/** `members-card`: a member and the card they were last issued. */
export const card = defineCallable({
  input: memberCardInput,
  handler: async (caller, input) => {
    const members = await service();
    return issuedJson(members, await members.card(caller, input));
  },
});

/**
 * `members-preview`: the card a member would get and the number on it.
 * Nothing is saved.
 */
export const preview = defineCallable({
  options: drawsCards,
  input: previewCardInput,
  handler: async (caller, input) => {
    const members = await service();
    const photo = photoOf(input.photo);
    const { number, pdf } = await members.preview(caller, { ...input, photo });
    return { number: number.digits, label: number.label, card: { pdf: base64(pdf) } };
  },
});

/**
 * `members-create`: adds a member and returns them with their card. A typed
 * number someone holds returns `taken` instead, until sent with `replace`.
 */
export const create = defineCallable({
  options: drawsCards,
  input: newMemberInput,
  handler: async (caller, input) => {
    const members = await service();
    const photo = bytes(input.photo);
    return issuedJson(members, await members.create(caller, { ...input, photo }));
  },
});

/** `members-update`: changes a member's details, and their card if it shows them. */
export const update = defineCallable({
  options: drawsCards,
  input: updateMemberInput,
  handler: async (caller, input) => {
    const members = await service();
    const photo = photoOf(input.photo);
    return issuedJson(members, await members.update(caller, { ...input, photo }));
  },
});
