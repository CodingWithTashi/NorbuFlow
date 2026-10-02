import 'package:norbu_flow/core/data/backend.dart';

/// Stands in for the Cloud Functions: answers every call with [response],
/// or fails with [error], and records what it was asked.
class FakeBackend implements Backend {
  FakeBackend(this.response);

  /// As the platform channel delivers it: nested objects are untyped maps.
  Map<String, Object?> response;
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
    return response;
  }
}
