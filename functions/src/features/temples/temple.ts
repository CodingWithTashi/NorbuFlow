/** What a person does at a temple. The names are the app's `Role` values. */
export const roles = [
  'admin',
  'geshe',
  'accountant',
  'frontDesk',
  'coordinator',
  'volunteer',
  'member',
] as const;

export type Role = (typeof roles)[number];

/** How long a membership runs. */
export type MembershipTerm =
  /** Every membership ends on the same day of the year. */
  | { kind: 'fixedYearEnd'; month: number; day: number }
  /** Each runs this many months from the day it is bought or renewed. */
  | { kind: 'rolling'; months: number };

/** A tenant. What differs between temples is configuration on its row, not code. */
export interface Temple {
  id: string;
  name: string;
  /** A line about the temple, such as its tradition and city. May be empty. */
  description: string;
  /** Where "today" is decided for the temple's dates, e.g. `America/Toronto`. */
  timeZone: string;
  /** Which card artwork and layout this temple prints. */
  cardTemplate: string;
  membershipTerm: MembershipTerm;
  /** Where its logo is in the file store, once it has one. */
  logoKey: string | null;
}

/** A temple being registered. */
export interface NewTemple extends Omit<Temple, 'logoKey'> {
  /** Membership numbers: the first to hand out, and how they are written. */
  memberNumber: { next: string; prefix: string; minDigits: number };
}

/** A temple someone works at, and what they do there. */
export interface TempleRole {
  temple: Temple;
  role: Role;
}

export interface TempleRepository {
  /** The temples whose team includes `email`. */
  rolesOf(email: string): Promise<TempleRole[]>;

  find(id: string): Promise<Temple | undefined>;

  /** Adds a temple. False, and nothing added, if one already has its id. */
  create(temple: NewTemple): Promise<boolean>;

  setLogo(id: string, logoKey: string): Promise<void>;

  /** Puts `email` on the temple's team as `role`, or changes their role. */
  addStaff(templeId: string, email: string, role: Role): Promise<void>;
}
