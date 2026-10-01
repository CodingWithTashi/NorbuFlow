import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show ProviderException;

import 'app_failure.dart';

/// The single translation point from "anything that was thrown" to
/// [AppFailure].
///
/// When the Firebase repositories arrive, their error codes
/// (`FirebaseFunctionsException.code`, `FirebaseAuthException.code`) are
/// mapped here and nowhere else.
abstract final class FailureMapper {
  static AppFailure map(Object error) {
    return switch (error) {
      AppFailure() => error,
      // Riverpod wraps errors that cross a provider boundary.
      ProviderException(:final exception) => map(exception),
      TimeoutException() => TimeoutFailure(cause: error),
      _ => UnknownFailure(cause: error),
    };
  }
}

/// Runs [body] so that the only thing it can throw is an [AppFailure].
///
/// Every repository method goes through this, which is what lets the layers
/// above treat `AppFailure` as the only error type.
Future<T> guardFailures<T>(Future<T> Function() body) async {
  try {
    return await body();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(FailureMapper.map(error), stackTrace);
  }
}
