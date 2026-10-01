import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../data/temple_repositories.dart';
import '../../domain/role.dart';
import '../../domain/temple.dart';

/// The temples the signed-in person belongs to. Single source of truth for
/// temple details: saving settings updates this list and everything that
/// shows a temple name, logo or accent follows.
class TemplesViewModel extends AsyncNotifier<List<TempleMembership>> {
  @override
  Future<List<TempleMembership>> build() async {
    final user = ref.watch(authViewModelProvider.select((auth) => auth.user));
    if (user == null) return const [];
    return ref.watch(templeRepositoryProvider).fetchMemberships(user.id);
  }

  Future<Result<Temple>> saveTemple(Temple temple) async {
    final result = await runCommand(
      ref,
      () => ref.read(templeRepositoryProvider).updateTemple(temple),
      source: 'temple.update',
    );
    if (result case Ok(:final value) when ref.mounted) {
      state = AsyncData([
        for (final membership in state.value ?? const <TempleMembership>[])
          membership.temple.id == value.id
              ? membership.copyWith(temple: value)
              : membership,
      ]);
    }
    return result;
  }
}

final templesProvider =
    AsyncNotifierProvider<TemplesViewModel, List<TempleMembership>>(
      TemplesViewModel.new,
    );

/// Which temple the person is working in. Cleared on sign-out.
class CurrentTempleIdViewModel extends Notifier<String?> {
  @override
  String? build() {
    // Rebuilding on any sign-in change resets the selection to null.
    ref.watch(authViewModelProvider.select((auth) => auth.isSignedIn));
    return null;
  }

  void select(String templeId) => state = templeId;
}

final currentTempleIdProvider =
    NotifierProvider<CurrentTempleIdViewModel, String?>(
      CurrentTempleIdViewModel.new,
    );

/// The current temple id for temple-scoped providers. Watching this is what
/// makes a provider reload when the person switches temple.
final activeTempleIdProvider = Provider<String>((ref) {
  return ref.watch(currentTempleIdProvider) ??
      (throw const NoTempleSelectedFailure());
});

final currentMembershipProvider = Provider<TempleMembership?>((ref) {
  final id = ref.watch(currentTempleIdProvider);
  final memberships = ref.watch(templesProvider).value;
  if (id == null || memberships == null) return null;
  for (final membership in memberships) {
    if (membership.temple.id == id) return membership;
  }
  return null;
});

final currentTempleProvider = Provider<Temple?>(
  (ref) => ref.watch(currentMembershipProvider)?.temple,
);

/// The signed-in person's real role at the current temple.
final myRoleProvider = Provider<Role>(
  (ref) => ref.watch(currentMembershipProvider)?.role ?? Role.member,
);

/// A role the admin is previewing ("See their home screen"), if any.
class RolePreviewViewModel extends Notifier<Role?> {
  @override
  Role? build() {
    // A preview never survives a temple switch.
    ref.watch(currentTempleIdProvider);
    return null;
  }

  void preview(Role role) => state = role;

  void exit() => state = null;
}

final rolePreviewProvider = NotifierProvider<RolePreviewViewModel, Role?>(
  RolePreviewViewModel.new,
);

/// The role whose Home screen is shown: the preview if one is active.
final homeRoleProvider = Provider<Role>(
  (ref) => ref.watch(rolePreviewProvider) ?? ref.watch(myRoleProvider),
);
