import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/feedback/dialogs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/selection.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../domain/role.dart';
import '../../domain/temple.dart';
import '../temple_labels.dart';
import '../view_models/team_view_model.dart';
import '../view_models/temple_session.dart';

/// What the admin chose to do with a team member. The sheet only collects
/// the intent; the Team screen carries it out.
sealed class TeamMemberAction {
  const TeamMemberAction();
}

final class SaveRole extends TeamMemberAction {
  const SaveRole(this.role);

  final Role role;
}

final class PreviewRole extends TeamMemberAction {
  const PreviewRole(this.role);

  final Role role;
}

final class RemoveMember extends TeamMemberAction {
  const RemoveMember();
}

Future<TeamMemberAction?> showTeamMemberSheet(
  BuildContext context,
  TeamMember member,
) {
  final l10n = context.l10n;
  return showAppSheet<TeamMemberAction>(
    context: context,
    title: member.isYou ? l10n.teamYouSuffix(member.name) : member.name,
    builder: (_) => _MemberSheet(member: member),
  );
}

/// Returns the invited person, or null if the sheet was dismissed.
Future<TeamMember?> showInviteSheet(BuildContext context) {
  return showAppSheet<TeamMember>(
    context: context,
    title: context.l10n.teamInviteCta,
    builder: (_) => const _InviteSheet(),
  );
}

/// The seven roles as a single-choice list, each with what it can do.
class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selected, required this.onChanged});

  final Role selected;
  final ValueChanged<Role> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.teamRoleQuestion, style: context.type.sectionTitle),
        const SizedBox(height: 14),
        for (final role in Role.values) ...[
          OptionTile(
            title: role.label(l10n),
            subtitle: role.description(l10n),
            selected: role == selected,
            onTap: () => onChanged(role),
            minHeight: 72,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MemberSheet extends ConsumerStatefulWidget {
  const _MemberSheet({required this.member});

  final TeamMember member;

  @override
  ConsumerState<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<_MemberSheet> {
  late Role _role = widget.member.role;

  void _pick(Role role) {
    if (!widget.member.canTakeRole(role)) {
      ref
          .read(appMessengerProvider.notifier)
          .showFailure(
            const PermissionFailure(reason: PermissionReason.ownRole),
          );
      return;
    }
    setState(() => _role = role);
  }

  void _close(TeamMemberAction action) => Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final member = widget.member;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          member.invitePending
              ? l10n.teamPersonPending(member.email)
              : member.email,
          style: context.type.sans(
            16,
            color: context.colors.inkMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        _RolePicker(selected: _role, onChanged: _pick),
        const SizedBox(height: 6),
        PrimaryButton(
          label: member.invitePending
              ? l10n.teamResendInvite
              : l10n.teamSaveRole,
          onPressed: () => _close(SaveRole(_role)),
        ),
        const SizedBox(height: 14),
        SecondaryButton(
          label: l10n.teamSeeHome,
          onPressed: () => _close(PreviewRole(_role)),
        ),
        if (!member.isYou)
          LinkButton(
            label: member.invitePending
                ? l10n.teamCancelInvite
                : l10n.teamRemove,
            destructive: true,
            expand: true,
            onPressed: () => _close(const RemoveMember()),
          ),
        LinkButton(
          label: l10n.commonCancel,
          minHeight: 52,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _InviteSheet extends ConsumerWidget {
  const _InviteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final state = ref.watch(inviteViewModelProvider);
    final viewModel = ref.read(inviteViewModelProvider.notifier);
    final temple = ref.watch(currentTempleProvider);
    final inviter = ref.watch(
      authViewModelProvider.select((auth) => auth.user?.displayName ?? ''),
    );

    Future<void> submit() async {
      final invited = await viewModel.submit();
      if (invited != null && context.mounted) {
        Navigator.of(context).pop(invited);
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.teamInviteEmail,
          hint: l10n.commonEmailHint,
          value: state.email,
          onChanged: viewModel.setEmail,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          errorText: state.issue == null
              ? null
              : validationText(l10n, state.issue!),
        ),
        const SizedBox(height: 14),
        _RolePicker(selected: state.role, onChanged: viewModel.setRole),
        const SizedBox(height: 6),
        Text(l10n.teamInvitePreviewLabel, style: type.sectionTitle),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppPalette.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.line),
          ),
          child: Text(
            l10n.teamInvitePreview(
              temple?.nameEn ?? '',
              inviter,
              state.role.label(l10n),
            ),
            style: type.sans(16, color: AppPalette.paperInk, height: 1.6),
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l10n.teamSendInvite,
          onPressed: submit,
          busy: state.submitting,
        ),
        LinkButton(
          label: l10n.commonCancel,
          minHeight: 52,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
