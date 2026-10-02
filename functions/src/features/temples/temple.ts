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
  /** Where "today" is decided for the temple's dates, e.g. `America/Toronto`. */
  timeZone: string;
  /** Which card artwork and layout this temple prints. */
  cardTemplate: string;
  membershipTerm: MembershipTerm;
}

/** A temple someone works at, and what they do there. */
export interface TempleRole {
  temple: Temple;
  role: Role;
}

export interface TempleRepository {
  /** The temples whose team includes `email`. */
  rolesOf(email: string): Promise<TempleRole[]>;
}
