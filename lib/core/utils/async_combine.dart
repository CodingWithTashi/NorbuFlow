import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Combines two async values: an error from either wins, then loading, and
/// only when both have data is [combine] called.
AsyncValue<R> combineAsync<A, B, R>(
  AsyncValue<A> first,
  AsyncValue<B> second,
  R Function(A first, B second) combine,
) {
  if (first.hasError) return AsyncError(first.error!, first.stackTrace!);
  if (second.hasError) return AsyncError(second.error!, second.stackTrace!);
  if (!first.hasValue || !second.hasValue) return const AsyncLoading();
  return AsyncData(combine(first.requireValue, second.requireValue));
}
