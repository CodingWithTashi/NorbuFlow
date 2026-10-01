import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/utils/validators.dart';
import '../../data/temple_repositories.dart';
import '../../domain/role.dart';
import '../../domain/temple.dart';
import 'temple_session.dart';

/// The current temple's team, and the only place it is changed.
class TeamViewModel extends AsyncNotifier<List<TeamMember>> {
  late String _templeId;

  TeamRepository get _repository => ref.read(teamRepositoryProvider);

  @override
  Future<List<TeamMember>> build() {
    _templeId = ref.watch(activeTempleIdProvider);
    return ref.watch(teamRepositoryProvider).fetchTeam(_templeId);
  }

  List<TeamMember> get _team => state.value ?? const [];

  /// [notify] is false because the invite sheet shows the failure inline.
  Future<Result<TeamMember>> invite(String email, Role role) async {
    final result = await runCommand(
      ref,
      () => _repository.invite(_templeId, email: email, role: role),
      notify: false,
      source: 'team.invite',
    );
    if (result case Ok(:final value) when ref.mounted) {
      state = AsyncData([..._team, value]);
    }
    return result;
  }

  Future<Result<void>> resendInvite(String memberId) => runCommand(
    ref,
    () => _repository.resendInvite(_templeId, memberId),
    source: 'team.resendInvite',
  );

  Future<Result<TeamMember>> updateRole(TeamMember member, Role role) async {
    if (!member.canTakeRole(role)) {
      return runCommand(
        ref,
        () async =>
            throw const PermissionFailure(reason: PermissionReason.ownRole),
      );
    }
    final result = await runCommand(
      ref,
      () => _repository.updateRole(_templeId, member.id, role),
      source: 'team.updateRole',
    );
    if (result case Ok(:final value) when ref.mounted) {
      state = AsyncData([
        for (final existing in _team)
          existing.id == value.id ? value : existing,
      ]);
    }
    return result;
  }

  Future<Result<void>> remove(TeamMember member) async {
    final result = await runCommand(
      ref,
      () => _repository.remove(_templeId, member.id),
      source: 'team.remove',
    );
    if (result.isOk && ref.mounted) {
      state = AsyncData([
        for (final existing in _team)
          if (existing.id != member.id) existing,
      ]);
    }
    return result;
  }

  /// Undo for [remove].
  Future<void> restore(TeamMember member) async {
    final result = await runCommand(
      ref,
      () => _repository.restore(_templeId, member),
      source: 'team.restore',
    );
    if (result.isOk && ref.mounted) ref.invalidateSelf();
  }
}

final teamProvider = AsyncNotifierProvider<TeamViewModel, List<TeamMember>>(
  TeamViewModel.new,
);

@immutable
class InviteState {
  const InviteState({
    this.email = '',
    this.role = Role.frontDesk,
    this.issue,
    this.submitting = false,
  });

  final String email;
  final Role role;
  final ValidationIssue? issue;
  final bool submitting;

  InviteState copyWith({
    String? email,
    Role? role,
    ValidationIssue? Function()? issue,
    bool? submitting,
  }) {
    return InviteState(
      email: email ?? this.email,
      role: role ?? this.role,
      issue: issue == null ? this.issue : issue(),
      submitting: submitting ?? this.submitting,
    );
  }
}

/// Form state for the "Invite someone" sheet.
class InviteViewModel extends Notifier<InviteState> {
  @override
  InviteState build() => const InviteState();

  void setEmail(String value) =>
      state = state.copyWith(email: value, issue: () => null);

  void setRole(Role role) => state = state.copyWith(role: role);

  /// Returns the invited member, or null if the form needs attention.
  Future<TeamMember?> submit() async {
    final email = state.email.trim();
    final issue = Validators.requiredEmail(
      email,
      whenEmpty: ValidationIssue.theirEmailRequired,
    );
    if (issue != null) {
      state = state.copyWith(issue: () => issue);
      return null;
    }
    state = state.copyWith(submitting: true);
    final result = await ref
        .read(teamProvider.notifier)
        .invite(email, state.role);
    if (!ref.mounted) return result.valueOrNull;
    final failure = result.failureOrNull;
    final duplicate =
        failure is ConflictFailure &&
        failure.reason == ConflictReason.alreadyOnTeam;
    // Only a duplicate is about the address; anything else goes to a toast.
    if (failure != null && !duplicate) {
      ref.read(appMessengerProvider.notifier).showFailure(failure);
    }
    state = state.copyWith(
      submitting: false,
      issue: () => duplicate ? ValidationIssue.alreadyOnTeam : null,
    );
    return result.valueOrNull;
  }
}

final inviteViewModelProvider =
    NotifierProvider.autoDispose<InviteViewModel, InviteState>(
      InviteViewModel.new,
    );
