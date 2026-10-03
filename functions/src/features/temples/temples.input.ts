import { z } from 'zod';

import { noControlChars } from '../../core/validation';
import { cardTemplates, standardTemplate } from '../cards';
import { templeFeatures } from './temple';

// These requests come from the operator's terminal, not the app, so each
// message says in words what is wrong instead of naming a `ValidationIssue`.

// A logo is a small picture; nothing larger has a reason to arrive.
const maxLogoBytes = 5 * 1024 * 1024;

function isTimeZone(value: string): boolean {
  try {
    new Intl.DateTimeFormat('en', { timeZone: value });
    return true;
  } catch {
    return false;
  }
}

const templeId = z
  .string('Send the temple id.')
  .regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'Lower-case letters, digits and single hyphens only.')
  .max(60, 'At most 60 characters.');

const membership = z.discriminatedUnion(
  'kind',
  [
    z.object({
      kind: z.literal('rolling'),
      months: z.int('A whole number of months, 1 to 120.').min(1).max(120),
    }),
    z.object({
      kind: z.literal('fixedYearEnd'),
      month: z.int('A month, 1 to 12.').min(1).max(12),
      day: z.int('A day, 1 to 31.').min(1).max(31),
    }),
  ],
  'Either {"kind":"rolling","months":12} or {"kind":"fixedYearEnd","month":7,"day":31}.',
);

const memberNumber = z.object({
  next: z.int('A whole number, 1 or more.').min(1).default(1),
  prefix: z
    .string('Text, such as "JC-".')
    .regex(noControlChars, 'Typed letters only.')
    .max(10, 'At most 10 characters.')
    .default(''),
  minDigits: z.int('A whole number, 0 to 12.').min(0).max(12).default(0),
});

/** What `temples-create` takes. Only the name and the time zone must be sent. */
export const newTempleInput = z.object({
  // Left out, it is made from the name.
  id: templeId.optional(),
  name: z
    .string('Send the temple’s name.')
    .trim()
    .regex(noControlChars, 'Typed letters only.')
    .min(1, 'Send the temple’s name.')
    .max(80, 'At most 80 characters.'),
  description: z
    .string('Send text.')
    .trim()
    .regex(noControlChars, 'Typed letters only.')
    .max(200, 'At most 200 characters.')
    .default(''),
  timeZone: z
    .string('Send an IANA time zone, such as America/Toronto.')
    .refine(isTimeZone, 'Not an IANA time zone. Try America/Toronto.'),
  cardTemplate: z
    .string(`One of: ${cardTemplates.join(', ')}.`)
    .refine((value) => cardTemplates.includes(value), `One of: ${cardTemplates.join(', ')}.`)
    .default(standardTemplate),
  membership: membership.default({ kind: 'rolling', months: 12 }),
  memberNumber: memberNumber.default({ next: 1, prefix: '', minDigits: 0 }),
});

/** What `temples-setLogo` takes: the temple in the address, the image as the body. */
export const templeLogoInput = z.object({
  templeId,
  logo: z
    .instanceof(Buffer, { error: 'Send the image file as the body of the request.' })
    .refine((image) => image.length > 0, 'Send the image file as the body of the request.')
    .refine((image) => image.length <= maxLogoBytes, 'The image is larger than 5 MB.'),
});

/** What `temples-setFeatures` takes: everything the temple's app shows, each once. */
export const templeFeaturesInput = z.object({
  templeId,
  features: z
    .array(
      z.enum(templeFeatures, `One of: ${templeFeatures.join(', ')}.`),
      'Send a list, such as ["tab.members", "home.addMember"].',
    )
    .transform((features) => [...new Set(features)]),
});

/** What `temples-addAdmin` takes. */
export const templeAdminInput = z.object({
  templeId,
  email: z
    .string('Send the admin’s email.')
    .trim()
    .toLowerCase()
    .pipe(z.email('Not an email address.')),
});
