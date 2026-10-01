import '../../l10n/generated/app_localizations.dart';
import 'app_failure.dart';
import 'validation_issue.dart';

/// The only place an [AppFailure] becomes user-facing words.
String failureText(AppLocalizations l10n, AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.failureNetwork,
    TimeoutFailure() => l10n.failureTimeout,
    UnauthenticatedFailure() => l10n.failureUnauthenticated,
    PermissionFailure(:final reason) => switch (reason) {
      PermissionReason.general => l10n.failurePermission,
      PermissionReason.adminOnlyRoles => l10n.failureAdminOnlyRoles,
      PermissionReason.adminOnlySettings => l10n.failureAdminOnlySettings,
      PermissionReason.ownRole => l10n.failureOwnRole,
    },
    NotFoundFailure() => l10n.failureNotFound,
    ConflictFailure(:final reason) => switch (reason) {
      ConflictReason.general => l10n.failureConflict,
      ConflictReason.alreadyOnTeam => l10n.failureAlreadyOnTeam,
      ConflictReason.shiftFull => l10n.failureShiftFull,
    },
    ValidationFailure(:final issues) =>
      issues.isEmpty
          ? l10n.failureUnknown
          : validationText(l10n, issues.values.first),
    UnavailableFailure() => l10n.failureUnavailable,
    NoTempleSelectedFailure() => l10n.failureNoTemple,
    UnknownFailure() => l10n.failureUnknown,
  };
}

/// The only place a [ValidationIssue] becomes user-facing words.
String validationText(AppLocalizations l10n, ValidationIssue issue) {
  return switch (issue) {
    ValidationIssue.ownEmailRequired => l10n.validationOwnEmailRequired,
    ValidationIssue.theirEmailRequired => l10n.validationTheirEmailRequired,
    ValidationIssue.emailIncomplete => l10n.validationEmailIncomplete,
    ValidationIssue.memberNameRequired => l10n.validationMemberNameRequired,
    ValidationIssue.phoneTooShort => l10n.validationPhoneShort,
    ValidationIssue.donorRequired => l10n.validationDonorRequired,
    ValidationIssue.purposeRequired => l10n.validationPurposeRequired,
    ValidationIssue.contactIncomplete => l10n.validationContactIncomplete,
    ValidationIssue.sponsorRequired => l10n.validationSponsorRequired,
    ValidationIssue.templeNameRequired => l10n.validationTempleNameRequired,
    ValidationIssue.addressRequired => l10n.validationAddressRequired,
    ValidationIssue.alreadyOnTeam => l10n.failureAlreadyOnTeam,
  };
}
