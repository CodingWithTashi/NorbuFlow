import { z } from 'zod';

import { noControlChars } from '../../core/validation';

// A photo straight off a phone camera fits; nothing larger has a reason to arrive.
const maxPhotoBytes = 8 * 1024 * 1024;

// Ids are chosen by the app. A bad one is its bug, so it has no issue name.
const uuid = z.uuid();

const name = z
  .string('memberNameRequired')
  .trim()
  .regex(noControlChars, 'memberNameUnsupported')
  .min(1, 'memberNameRequired')
  .max(80, 'memberNameTooLong');

const digitsIn = (value: string) => value.replace(/\D/g, '').length;

// Not everyone has one, so it may be left out or empty. With its country
// code, a real number has ten to fifteen digits.
const phone = z
  .string('phoneTooShort')
  .trim()
  .regex(noControlChars, 'phoneTooShort')
  .max(40, 'phoneTooLong')
  .refine((value) => value === '' || digitsIn(value) >= 10, 'phoneTooShort')
  .refine((value) => digitsIn(value) <= 15, 'phoneTooLong')
  .optional();

// Not everyone has one, so it may be left out or empty.
const email = z
  .string('emailIncomplete')
  .trim()
  .toLowerCase()
  .max(254, 'emailIncomplete')
  .pipe(z.union([z.literal(''), z.email('emailIncomplete')]))
  .optional();

const photo = z
  .string('photoRequired')
  .min(1, 'photoRequired')
  .max(Math.ceil(maxPhotoBytes / 3) * 4, 'photoUnreadable')
  .pipe(z.base64('photoUnreadable'));

// A membership number typed by hand: digits, above zero. Zeros in front do not count.
const number = z
  .string('memberNumberInvalid')
  .trim()
  .max(30, 'memberNumberInvalid')
  .regex(/^0*[1-9][0-9]{0,14}$/, 'memberNumberInvalid')
  .transform((digits) => digits.replace(/^0+/, ''))
  .optional();

const templeId = z
  .string('templeRequired')
  .min(1, 'templeRequired')
  .max(60, 'templeRequired')
  .optional();

/**
 * What `members-create` takes: each value present, tidied and within its
 * limits. Whether the card can print it is the service's question.
 */
export const newMemberInput = z.object({
  // Names the card this request makes: sent again, it returns the same card.
  id: uuid,
  name,
  phone,
  email,
  photo,
  // Left out, the member gets the temple's next number.
  number,
  // Whether a number that is taken should be given to this person instead.
  replace: z.boolean().optional(),
  templeId,
});

/** What `members-preview` takes: a card to draw, for a new member or one on file. */
export const previewCardInput = z.object({
  // Whose card it is. Left out, it is a new member's.
  memberId: uuid.optional(),
  name,
  // Left out for a member on file, their photo is the one they have.
  photo: photo.optional(),
  number,
  templeId,
});

/** What `members-update` takes: a member's details as they should now be. */
export const updateMemberInput = z.object({
  // Names the card this change prints, if it prints one.
  id: uuid,
  memberId: uuid,
  name,
  phone,
  email,
  photo: photo.optional(),
  number,
  templeId,
});

// The app sends nothing at all when the caller works at one temple.
export const listMembersInput = z.object({ templeId }).nullish();

export const memberCardInput = z.object({ memberId: uuid, templeId });
