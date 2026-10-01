import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/feedback/dialogs.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/tiles.dart';
import '../../domain/role.dart';
import '../../domain/temple.dart';
import '../temple_labels.dart';
import '../view_models/team_view_model.dart';
import '../view_models/temple_session.dart';
import 'team_sheets.dart';

/// Who has access to this temple and what each person can do. Only the
/// Temple Admin can invite people or change roles.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final team = ref.watch(teamProvider);
    final temple = ref.watch(currentTempleProvider);
    final isAdmin = ref.watch(myRoleProvider).canManageTemple;
    final viewModel = ref.read(teamProvider.notifier);

    Future<void> saveRole(TeamMember member, Role role) async {
      if (role != member.role) {
        final result = await viewModel.updateRole(member, role);
        if (!result.isOk) return;
      }
      if (member.invitePending) {
        final resent = await viewModel.resendInvite(member.id);
        if (resent.isOk) ref.toast(l10n.toastInviteResent(member.email));
      } else if (role == member.role) {
        ref.toast(l10n.toastNoChanges);
      } else {
        ref.toast(
          l10n.toastRoleSaved(firstNameOf(member.name), role.label(l10n)),
        );
      }
    }

    Future<void> remove(TeamMember member) async {
      final pending = member.invitePending;
      final confirmed = await showConfirmDialog(
        context: context,
        title: pending
            ? l10n.teamCancelInviteTitle(member.name)
            : l10n.teamRemoveTitle(member.name),
        message: pending
            ? l10n.teamCancelInviteBody
            : l10n.teamRemoveBody(member.name, temple?.nameEn ?? ''),
        confirmLabel: pending ? l10n.teamCancelInviteYes : l10n.teamRemoveYes,
        cancelLabel: l10n.teamKeep,
      );
      if (!confirmed) return;
      final result = await viewModel.remove(member);
      if (!result.isOk) return;
      ref.toast(
        l10n.toastTeamRemoved(member.name),
        onUndo: () => viewModel.restore(member),
      );
    }

    Future<void> openMember(TeamMember member) async {
      if (!isAdmin) {
        ref
            .read(appMessengerProvider.notifier)
            .showFailure(
              const PermissionFailure(reason: PermissionReason.adminOnlyRoles),
            );
        return;
      }
      final action = await showTeamMemberSheet(context, member);
      if (action == null || !context.mounted) return;
      switch (action) {
        case SaveRole(:final role):
          await saveRole(member, role);
        case PreviewRole(:final role):
          ref.read(rolePreviewProvider.notifier).preview(role);
          context.go(AppRoutes.home);
        case RemoveMember():
          await remove(member);
      }
    }

    Future<void> invite() async {
      final invited = await showInviteSheet(context);
      if (invited != null) ref.toast(l10n.toastInviteSent(invited.email));
    }

    return AppPage(
      backLabel: l10n.navMore,
      onBack: () => context.popOrGo(AppRoutes.more),
      bottom: isAdmin
          ? PrimaryButton(
              label: l10n.teamInviteCta,
              icon: AppIcons.addPerson,
              onPressed: invite,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: l10n.teamTitle,
            subtitle: isAdmin ? l10n.teamNoteAdmin : l10n.teamNoteOther,
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: team,
            onRetry: () => ref.invalidate(teamProvider),
            data: (members) => GroupedCard(
              children: [
                for (final member in members)
                  _TeamRow(
                    member: member,
                    showChevron: isAdmin,
                    onTap: () => openMember(member),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.member,
    required this.showChevron,
    required this.onTap,
  });

  final TeamMember member;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListRow(
      leading: PersonAvatar(name: member.name, size: 48),
      title: member.isYou ? l10n.teamYouSuffix(member.name) : member.name,
      subtitle: member.email,
      minHeight: 80,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      showChevron: showChevron,
      onTap: onTap,
      footer: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          StatusPill(label: member.role.label(l10n), tone: PillTone.plain),
          if (member.invitePending)
            StatusPill(
              label: l10n.teamInvitePending,
              icon: AppIcons.hours,
              tone: PillTone.warning,
            ),
        ],
      ),
    );
  }
}
