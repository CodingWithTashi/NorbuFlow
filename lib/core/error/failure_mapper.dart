import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;

import 'app_failure.dart';
import 'validation_issue.dart';

/// The single translation point from "anything that was thrown" to
/// [AppFailure]. Firebase's error codes are mapped here and nowhere else.
abstract final class FailureMapper {
  static AppFailure map(Object error) {
    return switch (error) {
      AppFailure() => error,
      // Riverpod wraps errors that cross a provider boundary.
      ProviderException(:final exception) => map(exception),
      TimeoutException() => TimeoutFailure(cause: error),
      FirebaseFunctionsException() => _fromBackend(error),
      FirebaseAuthException() => _fromAuth(error),
      _ => UnknownFailure(cause: error),
    };
  }

  /// A failed Cloud Functions call. `details.reason` and `details.fields`
  /// name values of [PermissionReason], [ConflictReason] and [ValidationIssue].
  static AppFailure _fromBackend(FirebaseFunctionsException error) {
    final details = switch (error.details) {
      final Map<Object?, Object?> details => details,
      _ => const <Object?, Object?>{},
    };
    final reason = details['reason'];
    return switch (error.code) {
      'unauthenticated' => UnauthenticatedFailure(cause: error),
      'permission-denied' => PermissionFailure(
        reason:
            PermissionReason.values.asNameMap()[reason] ??
            PermissionReason.general,
        cause: error,
      ),
      'not-found' => NotFoundFailure(cause: error),
      'already-exists' || 'aborted' => ConflictFailure(
        reason:
            ConflictReason.values.asNameMap()[reason] ?? ConflictReason.general,
        cause: error,
      ),
      'invalid-argument' => ValidationFailure(
        _issues(details['fields']),
        cause: error,
      ),
      'resource-exhausted' => TooManyRequestsFailure(cause: error),
      'deadline-exceeded' => TimeoutFailure(cause: error),
      'unavailable' => NetworkFailure(cause: error),
      _ => UnknownFailure(cause: error),
    };
  }

  static Map<String, ValidationIssue> _issues(Object? fields) {
    if (fields is! Map) return const {};
    final known = ValidationIssue.values.asNameMap();
    return {
      for (final MapEntry(:key, :value) in fields.entries)
        '$key': ?known[value],
    };
  }

  /// A failed Firebase Authentication call.
  static AppFailure _fromAuth(FirebaseAuthException error) {
    return switch (error.code) {
      'network-request-failed' => NetworkFailure(cause: error),
      'too-many-requests' ||
      'quota-exceeded' => TooManyRequestsFailure(cause: error),
      'expired-action-code' || 'invalid-action-code' => SignInLinkFailure(
        reason: SignInLinkReason.invalid,
        cause: error,
      ),
      'invalid-email' => ValidationFailure(const {
        'email': ValidationIssue.emailIncomplete,
      }, cause: error),
      'user-disabled' => PermissionFailure(
        reason: PermissionReason.accountDisabled,
        cause: error,
      ),
      'user-not-found' ||
      'user-token-expired' ||
      'invalid-user-token' => UnauthenticatedFailure(cause: error),
      // Email-link sign-in is switched off in the Firebase console.
      'operation-not-allowed' => UnavailableFailure(cause: error),
      _ => UnknownFailure(cause: error),
    };
  }
}

/// Runs [body] so that the only thing it can throw is an [AppFailure]. Every
/// repository method goes through this.
Future<T> guardFailures<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(FailureMapper.map(error), stackTrace);
  }
}
