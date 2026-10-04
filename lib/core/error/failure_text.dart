import '../../l10n/generated/app_localizations.dart';
import 'app_failure.dart';
import 'validation_issue.dart';

/// The only place an [AppFailure] becomes user-facing words.
String failureText(AppLocalizations l10n, AppFailure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.failureNetwork,
    TimeoutFailure() => l10n.failureTimeout,
    UnauthenticatedFailure() => l10n.failureUnauthenticated,
    SignInLinkFailure(:final reason) => switch (reason) {
      SignInLinkReason.invalid => l10n.failureSignInLinkInvalid,
      SignInLinkReason.differentDevice => l10n.failureSignInLinkOtherDevice,
    },
    PermissionFailure(:final reason) => switch (reason) {
      PermissionReason.general => l10n.failurePermission,
      PermissionReason.adminOnlyRoles => l10n.failureAdminOnlyRoles,
      PermissionReason.adminOnlySettings => l10n.failureAdminOnlySettings,
      PermissionReason.ownRole => l10n.failureOwnRole,
      PermissionReason.accountDisabled => l10n.failureAccountDisabled,
      PermissionReason.notOnTeam => l10n.failureNotOnTeam,
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
    TooManyRequestsFailure() => l10n.failureTooManyRequests,
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
    ValidationIssue.emailNotInvited => l10n.validationEmailNotInvited,
    ValidationIssue.memberNameRequired => l10n.validationMemberNameRequired,
    ValidationIssue.memberNameTooLong => l10n.validationMemberNameTooLong,
    ValidationIssue.memberNameUnsupported =>
      l10n.validationMemberNameUnsupported,
    ValidationIssue.photoRequired => l10n.validationPhotoRequired,
    ValidationIssue.photoUnreadable => l10n.validationPhotoUnreadable,
    ValidationIssue.phoneTooShort => l10n.validationPhoneShort,
    ValidationIssue.phoneTooLong => l10n.validationPhoneLong,
    ValidationIssue.memberNumberInvalid => l10n.validationMemberNumberInvalid,
    ValidationIssue.letterNameRequired => l10n.validationLetterNameRequired,
    ValidationIssue.letterNameTooLong => l10n.validationLetterNameTooLong,
    ValidationIssue.letterBodyRequired => l10n.validationLetterBodyRequired,
    ValidationIssue.letterBodyTooLong => l10n.validationLetterBodyTooLong,
    ValidationIssue.letterBodyUnsupported =>
      l10n.validationLetterBodyUnsupported,
    ValidationIssue.letterDatePast => l10n.validationLetterDatePast,
    ValidationIssue.letterNumberInvalid => l10n.validationLetterNumberInvalid,
    ValidationIssue.donorRequired => l10n.validationDonorRequired,
    ValidationIssue.purposeRequired => l10n.validationPurposeRequired,
    ValidationIssue.contactIncomplete => l10n.validationContactIncomplete,
    ValidationIssue.sponsorRequired => l10n.validationSponsorRequired,
    ValidationIssue.templeNameRequired => l10n.validationTempleNameRequired,
    ValidationIssue.templeRequired => l10n.validationTempleRequired,
    ValidationIssue.addressRequired => l10n.validationAddressRequired,
    ValidationIssue.alreadyOnTeam => l10n.failureAlreadyOnTeam,
  };
}
