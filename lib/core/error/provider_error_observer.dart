import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_failure.dart';
import 'error_reporter.dart';
import 'failure_mapper.dart';

/// Reports every provider that fails to load, so read errors are logged in
/// one place rather than at each call site.
final class ProviderErrorObserver extends ProviderObserver {
  const ProviderErrorObserver();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    context.container
        .read(errorReporterProvider)
        .report(
          FailureMapper.map(error),
          stackTrace: stackTrace,
          source:
              context.provider.name ?? context.provider.runtimeType.toString(),
        );
  }
}

/// Retry policy for providers: only failures that can heal on their own are
/// retried, and only twice, so a real error reaches the screen quickly.
Duration? appRetryPolicy(int retryCount, Object error) {
  final failure = FailureMapper.map(error);
  if (!failure.isTransient || retryCount >= 2) return null;
  return Duration(milliseconds: 400 * (retryCount + 1));
}

/// Narrows a provider error to the [AppFailure] the UI understands.
extension AsyncFailure on AsyncValue<Object?> {
  AppFailure? get failure => hasError ? FailureMapper.map(error!) : null;
}
