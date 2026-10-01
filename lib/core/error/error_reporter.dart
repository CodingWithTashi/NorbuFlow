import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_failure.dart';

/// Where failures go to be recorded. Swap the provider for a Crashlytics
/// implementation once Firebase is wired in.
abstract interface class ErrorReporter {
  void report(AppFailure failure, {StackTrace? stackTrace, String? source});
}

final class LogErrorReporter implements ErrorReporter {
  const LogErrorReporter();

  @override
  void report(AppFailure failure, {StackTrace? stackTrace, String? source}) {
    developer.log(
      failure.toString(),
      name: source ?? 'norbu_flow',
      error: failure.cause ?? failure,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}

final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => const LogErrorReporter(),
);
