import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../../core/widgets/tiles.dart';
import '../../domain/member.dart';
import '../member_labels.dart';
import '../view_models/member_card_view_model.dart';
import '../view_models/members_view_model.dart';
import '../widgets/card_pages.dart';

/// A member full-screen, reached from a member row on phones.
class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    return MemberDetailView(
      memberId: memberId,
      backLabel: context.l10n.navMembers,
      onBack: () => context.popOrGo(AppRoutes.members),
    );
  }
}

/// A member as the backend has them: their card, their details, and ways to
/// print, change or reach them. On tablets, the pane beside the list.
class MemberDetailView extends ConsumerWidget {
  const MemberDetailView({
    super.key,
    required this.memberId,
    this.backLabel,
    this.onBack,
  });

  final String memberId;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(memberProvider(memberId)),
      onRetry: () => ref.invalidate(membersProvider),
      data: (member) => member == null
          ? AppPage(
              backLabel: backLabel,
              onBack: onBack,
              child: MessageView(message: context.l10n.cardNotFound),
            )
          : _MemberPage(member: member, backLabel: backLabel, onBack: onBack),
    );
  }
}

class _MemberPage extends ConsumerWidget {
  const _MemberPage({required this.member, this.backLabel, this.onBack});

  final Member member;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final actions = ref.read(memberActionsProvider);
    final status = member.statusOn(ref.watch(todayProvider));
    final expiry = member.expiresOn;
    final title = l10n.newCardDocumentName(member.number);

    return AppPage(
      backLabel: backLabel,
      onBack: onBack,
      padding: EdgeInsets.fromLTRB(20, backLabel == null ? 20 : 0, 20, 16),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: l10n.newCardPrint,
            icon: AppIcons.print,
            onPressed: () => actions.printCard(member.id, title),
          ),
          const SizedBox(height: 10),
          EqualRow(
            children: [
              SecondaryButton(
                label: l10n.newCardShare,
                fontSize: 16,
                onPressed: () => actions.shareCard(member.id, title),
              ),
              SecondaryButton(
                label: l10n.memberEdit,
                fontSize: 16,
                onPressed: () => context.go(AppRoutes.editMember(member.id)),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(member.nameEn, style: type.screenTitle),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.memberNumber(member.number),
                style: type.sans(16, color: colors.inkMuted, height: 1.4),
              ),
              MembershipStatusPill(status),
            ],
          ),
          const SizedBox(height: 18),
          AsyncValueView(
            value: ref.watch(memberCardProvider(member.id)),
            onRetry: () => ref.invalidate(memberCardProvider(member.id)),
            data: (onFile) => Center(child: CardPages(onFile.pages)),
          ),
          const SizedBox(height: 18),
          GroupedCard(
            children: [
              _Fact(
                label: l10n.addFieldPhone,
                value: member.phone.isEmpty
                    ? l10n.memberNotGiven
                    : member.phone,
              ),
              _Fact(
                label: l10n.addFieldEmail,
                value: member.email.isEmpty
                    ? l10n.memberNotGiven
                    : member.email,
              ),
              _Fact(
                label: l10n.addValidUntil,
                value: expiry == null
                    ? l10n.commonLifetime
                    : Formats.date(expiry),
              ),
            ],
          ),
          // Only the ways this member can be reached are offered.
          if (member.email.isNotEmpty || member.phone.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(l10n.memberContactTitle, style: type.sectionTitle),
            const SizedBox(height: 12),
            ShareActionRow(
              actions: [
                if (member.email.isNotEmpty)
                  ShareAction(
                    icon: AppIcons.mail,
                    label: l10n.commonEmail,
                    onTap: () => actions.email(member),
                  ),
                if (member.phone.isNotEmpty)
                  ShareAction(
                    icon: AppIcons.chat,
                    label: l10n.commonWhatsApp,
                    onTap: () => actions.whatsApp(member),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A caption and its value on one row, the value wrapping if it must.
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 12,
          children: [
            Text(label, style: type.sans(16, color: context.colors.inkMuted)),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: type.sans(17, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
