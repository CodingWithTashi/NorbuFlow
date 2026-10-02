import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../domain/member.dart';
import '../member_labels.dart';
import '../view_models/members_view_model.dart';
import 'member_card_view.dart';
import 'member_detail_view.dart';

/// The member directory. On phones a row opens the member; on tablets they
/// appear beside the list.
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= Breakpoints.expanded;
        if (!twoPane) {
          return _MemberList(
            onOpen: (member) => context.go(AppRoutes.member(member.id)),
          );
        }
        final selectedId = ref.watch(selectedMemberProvider);
        final demo = ref.watch(appConfigProvider).demoMembers;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 400,
              child: _MemberList(
                selectedId: selectedId,
                onOpen: (member) =>
                    ref.read(selectedMemberProvider.notifier).select(member.id),
              ),
            ),
            VerticalDivider(width: 1, color: context.colors.line),
            Expanded(
              child: selectedId == null
                  ? MessageView(message: context.l10n.membersSelectHint)
                  : demo
                  ? MemberCardView(
                      key: ValueKey(selectedId),
                      memberId: selectedId,
                    )
                  : MemberDetailView(
                      key: ValueKey(selectedId),
                      memberId: selectedId,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({required this.onOpen, this.selectedId});

  final ValueChanged<Member> onOpen;

  /// Highlighted row in the two-pane layout.
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final list = ref.watch(memberListProvider);
    final due = ref.watch(membershipDueProvider);
    final today = ref.watch(todayProvider);
    final query = ref.watch(memberSearchProvider);

    return ColoredBox(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.membersTitle, style: type.screenTitle),
                ),
                const SizedBox(height: 6),
                if (list.value case final state?)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.isSearching
                        ? [
                            StatusPill(
                              label: l10n.membersFoundCount(
                                state.visible.length,
                              ),
                              tone: PillTone.plain,
                              height: 30,
                              fontSize: 14,
                            ),
                          ]
                        : [
                            StatusPill(
                              label: l10n.membersCount(state.total),
                              tone: PillTone.plain,
                              height: 30,
                              fontSize: 14,
                            ),
                            StatusPill(
                              label: l10n.membersExpiringCount(due.expiring),
                              icon: MembershipStatus.expiring.icon,
                              tone: PillTone.warning,
                              height: 30,
                              fontSize: 14,
                            ),
                            StatusPill(
                              label: l10n.membersExpiredCount(due.expired),
                              icon: MembershipStatus.expired.icon,
                              tone: PillTone.danger,
                              height: 30,
                              fontSize: 14,
                            ),
                          ],
                  ),
                const SizedBox(height: 12),
                SearchField(
                  value: query,
                  hint: l10n.commonSearchHint,
                  onChanged: ref.read(memberSearchProvider.notifier).setQuery,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: list,
              onRetry: () => ref.invalidate(membersProvider),
              data: (state) {
                if (state.visible.isEmpty) {
                  return MessageView(
                    message:
                        '${l10n.membersNoResults(state.query.trim())}\n'
                        '${l10n.membersNoResultsHint}',
                  );
                }
                return RefreshIndicator(
                  color: colors.accentText,
                  backgroundColor: colors.surface,
                  onRefresh: ref.read(membersProvider.notifier).refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: state.visible.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.line),
                    itemBuilder: (context, index) {
                      final member = state.visible[index];
                      return _MemberRow(
                        member: member,
                        status: member.statusOn(today),
                        selected: member.id == selectedId,
                        onTap: () => onOpen(member),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          BottomActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: l10n.membersAddCta,
                  onPressed: () => context.go(AppRoutes.addMember),
                ),
                // With the backend on, Add a Member already opens New ID card.
                if (ref.watch(appConfigProvider).demoMembers)
                  LinkButton(
                    label: l10n.membersNewCard,
                    onPressed: () => context.go(AppRoutes.newCard),
                    expand: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final Member member;
  final MembershipStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Material(
      color: selected ? colors.card : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                PersonAvatar(name: member.nameEn, photo: member.photo),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        member.nameEn,
                        style: type.sans(
                          18,
                          weight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (member.nameBo.isNotEmpty)
                        Text(
                          member.nameBo,
                          style: type.tibetan(15, color: colors.inkMuted),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            member.number,
                            style: type
                                .sans(14, color: colors.inkMuted, height: 1.3)
                                .copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: MembershipStatusPill(status)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppIcon(
                  AppIcons.chevronRight,
                  size: 20,
                  color: colors.inkMuted,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
