import { toIsoDate } from '../../core/calendar-date';
import { defineCallable } from '../../core/callable';
import { lazy } from '../../core/lazy';
import { database, fileStore } from '../../runtime';
import { cardRenderer } from '../cards';
import { templeAccess } from '../temples';
import { newMemberInput } from './members.input';
import { MemberService } from './members.service';
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

/**
 * `members-create`: adds a member from their details and a photo, and
 * returns their membership number with the card, ready to print.
 */
export const create = defineCallable({
  options: { memory: '1GiB', timeoutSeconds: 60 },
  input: newMemberInput,
  handler: async (caller, input) => {
    const members = await service();
    const photo = Buffer.from(input.photo, 'base64');
    const { member, pdf } = await members.create(caller, { ...input, photo });
    return {
      member: {
        id: member.id,
        number: member.number,
        name: member.name,
        email: member.email,
        phone: member.phone,
        joinedOn: toIsoDate(member.joinedOn),
        renewedOn: toIsoDate(member.renewedOn),
        expiresOn: toIsoDate(member.expiresOn),
      },
      card: { pdf: Buffer.from(pdf).toString('base64') },
    };
  },
});
