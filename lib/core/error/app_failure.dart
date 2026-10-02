import 'validation_issue.dart';

/// Every error the app can surface, as one closed hierarchy: what
/// repositories throw, view models expose and `failureText` puts into words.
sealed class AppFailure implements Exception {
  const AppFailure({this.cause});

  /// The underlying error, kept for logging only. Never shown to the user.
  final Object? cause;

  /// Whether retrying the same call may succeed without the user changing
  /// anything. Drives the provider retry policy.
  bool get isTransient => false;

  @override
  String toString() => '$runtimeType${cause == null ? '' : '($cause)'}';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause});

  @override
  bool get isTransient => true;
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.cause});

  @override
  bool get isTransient => true;
}

final class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure({super.cause});
}

enum SignInLinkReason {
  /// Expired, already used, or sent to a different address.
  invalid,

  /// Opened on a device that did not ask for it.
  differentDevice,
}

/// An emailed sign-in link that cannot be used. A new one is the only fix.
final class SignInLinkFailure extends AppFailure {
  const SignInLinkFailure({required this.reason, super.cause});

  final SignInLinkReason reason;
}

enum PermissionReason {
  general,
  adminOnlyRoles,
  adminOnlySettings,
  ownRole,
  accountDisabled,

  /// Signed in, but no temple has added this email to its team.
  notOnTeam,
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure({
    this.reason = PermissionReason.general,
    super.cause,
  });

  final PermissionReason reason;
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.cause});
}

enum ConflictReason { general, alreadyOnTeam, shiftFull }

final class ConflictFailure extends AppFailure {
  const ConflictFailure({this.reason = ConflictReason.general, super.cause});

  final ConflictReason reason;
}

/// Input the backend rejected, keyed by the field it belongs to.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(this.issues, {super.cause});

  final Map<String, ValidationIssue> issues;
}

/// A dependency (AI help, printing, …) that is not reachable right now.
final class UnavailableFailure extends AppFailure {
  const UnavailableFailure({super.cause});
}

/// Too many attempts in a short time. Waiting is the only fix.
final class TooManyRequestsFailure extends AppFailure {
  const TooManyRequestsFailure({super.cause});
}

/// A temple-scoped call was made before a temple was chosen.
final class NoTempleSelectedFailure extends AppFailure {
  const NoTempleSelectedFailure();
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause});
}
