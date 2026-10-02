import 'package:norbu_flow/core/data/backend.dart';

/// Stands in for the Cloud Functions: answers with [response], or [answers]
/// for that function, or fails with [error]. Records what it was asked.
class FakeBackend implements Backend {
  FakeBackend(this.response, {Map<String, Map<String, Object?>>? answers})
    : answers = answers ?? {};

  /// As the platform channel delivers it: nested objects are untyped maps.
  Map<String, Object?> response;

  /// By function name, for a test that calls more than one.
  final Map<String, Map<String, Object?>> answers;
  Object? error;

  final calls = <String>[];
  final inputs = <Map<String, Object?>?>[];
  final timeouts = <Duration>[];

  @override
  Future<Map<String, Object?>> call(
    String function, {
    Map<String, Object?>? input,
    Duration timeout = Backend.defaultTimeout,
  }) async {
    calls.add(function);
    inputs.add(input);
    timeouts.add(timeout);
    if (error case final error?) throw error;
    return answers[function] ?? response;
  }
}
