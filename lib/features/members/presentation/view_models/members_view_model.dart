import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/clock.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/member_repositories.dart';
import '../../domain/member.dart';

/// The current temple's members. Every screen that shows or changes a member
/// (list, ID card, check-in, reports) reads from here, so a renewal made on
/// one screen is reflected on all of them.
class MembersViewModel extends AsyncNotifier<List<Member>> {
  late String _templeId;

  MemberRepository get _repository => ref.read(memberRepositoryProvider);

  @override
  Future<List<Member>> build() {
    _templeId = ref.watch(activeTempleIdProvider);
    return ref.watch(memberRepositoryProvider).fetchMembers(_templeId);
  }

  List<Member> get _members => state.value ?? const [];

  Future<Result<Member>> add(NewMember newMember) async {
    final result = await runCommand(
      ref,
      () => _repository.addMember(_templeId, newMember),
      source: 'members.add',
    );
    if (result case Ok(:final value) when ref.mounted) {
      state = AsyncData([value, ..._members]);
    }
    return result;
  }

  Future<Result<Member>> renew(String memberId) async {
    final result = await runCommand(
      ref,
      () => _repository.renew(_templeId, memberId),
      source: 'members.renew',
    );
    if (result case Ok(:final value) when ref.mounted) {
      state = AsyncData([
        for (final member in _members) member.id == value.id ? value : member,
      ]);
    }
    return result;
  }

  Future<Result<CheckIn>> checkIn(String memberId) => runCommand(
    ref,
    () => _repository.checkIn(_templeId, memberId),
    source: 'members.checkIn',
  );
}

final membersProvider = AsyncNotifierProvider<MembersViewModel, List<Member>>(
  MembersViewModel.new,
);

/// One member by id, or null if they are not in the current temple.
final memberProvider = Provider.autoDispose.family<AsyncValue<Member?>, String>(
  (ref, memberId) => ref
      .watch(membersProvider)
      .whenData(
        (members) => members.where((m) => m.id == memberId).firstOrNull,
      ),
);

/// How many memberships need attention, for the list header and Reports.
@immutable
class MembershipDue {
  const MembershipDue({required this.expiring, required this.expired});

  final int expiring;
  final int expired;
}

final membershipDueProvider = Provider.autoDispose<MembershipDue>((ref) {
  final today = ref.watch(todayProvider);
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  int count(MembershipStatus status) =>
      members.where((m) => m.statusOn(today) == status).length;
  return MembershipDue(
    expiring: count(MembershipStatus.expiring),
    expired: count(MembershipStatus.expired),
  );
});

/// Search text on the Members list.
class MemberSearchViewModel extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final memberSearchProvider =
    NotifierProvider.autoDispose<MemberSearchViewModel, String>(
      MemberSearchViewModel.new,
    );

@immutable
class MemberListState {
  const MemberListState({
    required this.query,
    required this.total,
    required this.visible,
  });

  final String query;

  /// Members in the temple, before filtering.
  final int total;
  final List<Member> visible;

  bool get isSearching => query.trim().isNotEmpty;
}

final memberListProvider = Provider.autoDispose<AsyncValue<MemberListState>>((
  ref,
) {
  final query = ref.watch(memberSearchProvider);
  return ref
      .watch(membersProvider)
      .whenData(
        (members) => MemberListState(
          query: query,
          total: members.length,
          visible: members.where((m) => m.matches(query)).toList(),
        ),
      );
});

/// On tablets the Members screen shows the chosen member's card beside the
/// list instead of navigating to it.
class SelectedMemberViewModel extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(currentTempleIdProvider);
    return null;
  }

  void select(String memberId) => state = memberId;
}

final selectedMemberProvider =
    NotifierProvider<SelectedMemberViewModel, String?>(
      SelectedMemberViewModel.new,
    );
