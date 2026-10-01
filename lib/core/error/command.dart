import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/app_messenger.dart';
import 'error_reporter.dart';
import 'failure_mapper.dart';
import 'result.dart';

/// Runs a write on behalf of a view model.
///
/// This is the one place command errors are handled: the error is normalised
/// to an `AppFailure`, reported, and (unless [notify] is false because the
/// caller will show it inline) surfaced to the user as a toast. View models
/// just branch on the returned [Result].
Future<Result<T>> runCommand<T>(
  Ref ref,
  Future<T> Function() action, {
  bool notify = true,
  String? source,
}) async {
  // Resolved up front: the calling provider may be disposed by the time the
  // action completes, after which `ref` can no longer be used.
  final reporter = ref.read(errorReporterProvider);
  final messenger = ref.read(appMessengerProvider.notifier);
  try {
    return Ok(await action());
  } catch (error, stackTrace) {
    final failure = FailureMapper.map(error);
    reporter.report(failure, stackTrace: stackTrace, source: source);
    if (notify) messenger.showFailure(failure);
    return Err(failure);
  }
}
