import { randomUUID } from 'node:crypto';

import type { Caller } from '../../core/caller';
import { AppError } from '../../core/errors';
import type { FileStore } from '../../core/file-store';
import type { NameProblem } from '../cards';
import type { Accounts } from './accounts';
import {
  defaultFeatures,
  type MembershipTerm,
  type Role,
  type Temple,
  type TempleFeature,
  type TempleRepository,
} from './temple';
import type { TempleAccess } from './temple-access';
import { prepareLogo } from './temple-logo';

/** A temple to register, as `temples.input.ts` leaves it: tidied, with its defaults. */
export interface NewTempleRequest {
  /** Left out, it is made from the name. */
  id?: string;
  name: string;
  description: string;
  timeZone: string;
  cardTemplate: string;
  membership: MembershipTerm;
  memberNumber: { next: number; prefix: string; minDigits: number };
}

/** A temple someone works at, as the app's temple list shows it. */
export interface TempleListing {
  temple: Temple;
  role: Role;
  /** A PNG, if the temple has a logo. */
  logo?: Uint8Array;
}

/** Registering temples and saying who runs them. No HTTP, no Firebase, no SQL. */
export class TempleService {
  constructor(
    private readonly temples: TempleRepository,
    private readonly access: TempleAccess,
    private readonly files: FileStore,
    private readonly accounts: Accounts,
    private readonly nameProblem: (
      template: string,
      name: string,
    ) => Promise<NameProblem | undefined>,
  ) {}

  /** Registers a temple. Its id is taken from its name unless one is sent. */
  async create(request: NewTempleRequest): Promise<Temple> {
    const id = request.id ?? idFromName(request.name);
    if (!id) throw AppError.invalid({ id: 'The name has no Latin letters. Send an "id" as well.' });

    const problem = await this.nameProblem(request.cardTemplate, request.name);
    if (problem === 'unsupported') {
      throw AppError.invalid({ name: 'The standard card prints Latin letters only.' });
    }
    if (problem === 'tooLong') {
      throw AppError.invalid({ name: 'Too long for the standard card, which has two lines.' });
    }

    const { next, prefix, minDigits } = request.memberNumber;
    const added = await this.temples.create({
      id,
      name: request.name,
      description: request.description,
      timeZone: request.timeZone,
      cardTemplate: request.cardTemplate,
      membershipTerm: request.membership,
      features: defaultFeatures,
      memberNumber: { next: String(next), prefix, minDigits },
    });
    if (!added) {
      // Sent twice, or two temples share a name: never a second temple by accident.
      const existing = await this.temples.find(id);
      throw AppError.conflict(
        `"${existing?.name}" already has the id "${id}". Send another "id" to register a different temple.`,
        'templeExists',
      );
    }
    return this.existing(id);
  }

  /** Replaces what the temple's app shows with `features`. */
  async setFeatures(templeId: string, features: TempleFeature[]): Promise<Temple> {
    const temple = await this.existing(templeId);
    await this.temples.setFeatures(temple.id, features);
    return this.existing(temple.id);
  }

  /** Replaces the temple's logo with `image`. Earlier logos stay in the file store. */
  async setLogo(templeId: string, image: Uint8Array): Promise<Temple> {
    const temple = await this.existing(templeId);
    const logo = await prepareLogo(image);
    if (!logo) throw AppError.invalid({ logo: 'Not a picture. Send a PNG or a JPEG.' });

    // A new key each time, so nothing goes on showing the old logo.
    const logoKey = `temples/${temple.id}/logo-${randomUUID()}.png`;
    await this.files.put(logoKey, logo, 'image/png');
    await this.temples.setLogo(temple.id, logoKey);
    return { ...temple, logoKey };
  }

  /**
   * Assigns the temple to `email` as its admin, and makes sure that address
   * has an account. Nothing is sent: they ask for a sign-in link in the app.
   */
  async addAdmin(templeId: string, email: string): Promise<Temple> {
    const temple = await this.existing(templeId);
    await this.accounts.ensure(email);
    await this.temples.addStaff(temple.id, email, 'admin');
    return temple;
  }

  /** The temples the caller works at, with their logos. */
  async templesOf(caller: Caller): Promise<TempleListing[]> {
    const roles = await this.access.rolesOf(caller);
    return Promise.all(
      roles.map(async ({ temple, role }) => ({ temple, role, logo: await this.logoOf(temple) })),
    );
  }

  /** A logo that cannot be read is left out: its temple is still listed. */
  private async logoOf(temple: Temple): Promise<Uint8Array | undefined> {
    if (!temple.logoKey) return undefined;
    try {
      return await this.files.get(temple.logoKey);
    } catch (error) {
      console.warn(`The logo of ${temple.id} could not be read.`, error);
      return undefined;
    }
  }

  private async existing(templeId: string): Promise<Temple> {
    const temple = await this.temples.find(templeId);
    if (!temple) throw AppError.notFound(`No temple has the id "${templeId}".`);
    return temple;
  }
}

/** `Drepung Loseling Canada` → `drepung-loseling-canada`. Empty if nothing is left. */
export function idFromName(name: string): string {
  return name
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
    .replace(/-+$/, '');
}
