import { z } from 'zod';

/** What `auth-checkEmail` takes: the address someone typed on the sign-in screen. */
export const checkEmailInput = z.object({
  email: z
    .string('ownEmailRequired')
    .trim()
    .toLowerCase()
    .min(1, 'ownEmailRequired')
    // No real address is longer, and anyone at all may send this.
    .max(254, 'emailIncomplete')
    .pipe(z.email('emailIncomplete')),
});
