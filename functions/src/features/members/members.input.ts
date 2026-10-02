import { z } from 'zod';

// A photo straight off a phone camera fits; nothing larger has a reason to arrive.
const maxPhotoBytes = 8 * 1024 * 1024;

// Typed text has no control characters, one of which Postgres cannot store.
const noControlChars = /^\P{Cc}*$/u;

/**
 * What `members-create` takes: each value present, tidied and within its
 * limits. Whether the card can print it is the service's question.
 */
export const newMemberInput = z.object({
  // The app's name for this member. Sending it again returns the same member.
  id: z.uuid(),
  name: z
    .string('memberNameRequired')
    .trim()
    .regex(noControlChars, 'memberNameUnsupported')
    .min(1, 'memberNameRequired')
    .max(80, 'memberNameTooLong'),
  phone: z
    .string('phoneTooShort')
    .trim()
    .regex(noControlChars, 'phoneTooShort')
    .max(40, 'phoneTooShort')
    .refine((value) => value.replace(/\D/g, '').length >= 10, 'phoneTooShort'),
  // Not everyone has one, so it may be left out or empty.
  email: z
    .string('emailIncomplete')
    .trim()
    .toLowerCase()
    .pipe(z.union([z.literal(''), z.email('emailIncomplete')]))
    .optional(),
  photo: z
    .string('photoRequired')
    .min(1, 'photoRequired')
    .max(Math.ceil(maxPhotoBytes / 3) * 4, 'photoUnreadable')
    .pipe(z.base64('photoUnreadable')),
  templeId: z.string('templeRequired').min(1, 'templeRequired').optional(),
});
