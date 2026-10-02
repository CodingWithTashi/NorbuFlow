import type { Caller } from '../../core/caller';
import { AppError } from '../../core/errors';
import type { Role, Temple, TempleRepository, TempleRole } from './temple';

/** Decides which temple a call is about and whether the caller may make it. */
export class TempleAccess {
  constructor(private readonly temples: TempleRepository) {}

  /** The temples the caller works at. Invite-only: on no team, they are turned away. */
  async rolesOf(caller: Caller): Promise<TempleRole[]> {
    const roles = await this.temples.rolesOf(caller.email);
    if (roles.length === 0) {
      throw AppError.permissionDenied(`${caller.email} is on no temple's team.`, 'notOnTeam');
    }
    return roles;
  }

  /**
   * The temple the caller is working in, if their role there is one of
   * `allowed`. Someone who works at a single temple may leave `templeId` out.
   */
  async templeFor(caller: Caller, templeId: string | undefined, allowed: Role[]): Promise<Temple> {
    const roles = await this.rolesOf(caller);
    if (roles.length > 1 && templeId === undefined) {
      throw AppError.invalid({ templeId: 'templeRequired' });
    }
    const found = templeId === undefined ? roles[0] : roles.find((r) => r.temple.id === templeId);
    if (!found) {
      throw AppError.permissionDenied(`${caller.email} is not on this temple's team.`, 'notOnTeam');
    }
    if (!allowed.includes(found.role)) {
      throw AppError.permissionDenied(`A ${found.role} may not do this at ${found.temple.id}.`);
    }
    return found.temple;
  }
}
