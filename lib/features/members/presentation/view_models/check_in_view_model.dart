import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/member.dart';
import 'members_view_model.dart';

@immutable
class CheckInState {
  const CheckInState({this.query = '', this.result, this.busy = false});

  final String query;

  /// The most recent successful check-in, shown until "Check in someone
  /// else" is tapped.
  final CheckIn? result;
  final bool busy;
}

class CheckInViewModel extends Notifier<CheckInState> {
  /// Name matches shown under the search box.
  static const maxMatches = 4;

  @override
  CheckInState build() => const CheckInState();

  void setQuery(String query) =>
      state = CheckInState(query: query, result: state.result);

  Future<void> checkIn(String memberId) async {
    if (state.busy) return;
    state = CheckInState(query: state.query, result: state.result, busy: true);
    final result = await ref.read(membersProvider.notifier).checkIn(memberId);
    if (!ref.mounted) return;
    state = result.isOk
        ? CheckInState(result: result.valueOrNull)
        : CheckInState(query: state.query, result: state.result);
  }

  void reset() => state = const CheckInState();
}

final checkInViewModelProvider =
    NotifierProvider.autoDispose<CheckInViewModel, CheckInState>(
      CheckInViewModel.new,
    );

/// Members matching the check-in search, capped to a short list.
final checkInMatchesProvider = Provider.autoDispose<List<Member>>((ref) {
  final query = ref.watch(checkInViewModelProvider.select((s) => s.query));
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  return members
      .where((m) => m.matches(query))
      .take(CheckInViewModel.maxMatches)
      .toList();
});
