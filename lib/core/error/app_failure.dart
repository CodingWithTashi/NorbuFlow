import 'validation_issue.dart';

/// Every error the app can surface, as one closed hierarchy.
///
/// Repositories only ever throw [AppFailure] (see `guardFailures`), view
/// models only ever expose [AppFailure], and the UI turns one into words in
/// exactly one place (`failureText`). Adding a new kind of failure therefore
/// means adding a subclass here and a line there — the compiler flags the
/// rest.
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

enum PermissionReason { general, adminOnlyRoles, adminOnlySettings, ownRole }

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

/// A temple-scoped call was made before a temple was chosen.
final class NoTempleSelectedFailure extends AppFailure {
  const NoTempleSelectedFailure();
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause});
}
