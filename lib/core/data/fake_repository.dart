import 'package:flutter/foundation.dart';

import '../error/failure_mapper.dart';

/// Base for the in-memory repositories that stand in for Firebase.
///
/// [respond] gives every fake the two properties the real backend will have:
/// calls take time, and anything that goes wrong surfaces as an `AppFailure`.
abstract class FakeRepository {
  FakeRepository(this._latency);

  final Duration _latency;

  @protected
  Future<T> respond<T>(T Function() body) {
    return guardFailures(() async {
      if (_latency > Duration.zero) await Future<void>.delayed(_latency);
      return body();
    });
  }
}
