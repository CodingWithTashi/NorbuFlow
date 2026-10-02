import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/outbox_actions.dart';
import '../../../outbox/presentation/send_preview_sheet.dart';
import '../../../temple/domain/temple.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/member.dart';
import '../member_labels.dart';
import '../view_models/members_view_model.dart';
import '../widgets/membership_card.dart';

/// Full-screen ID card, reached from a member row on phones.
class MemberCardScreen extends StatelessWidget {
  const MemberCardScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context) {
    return MemberCardView(
      memberId: memberId,
      backLabel: context.l10n.navMembers,
      onBack: () => context.popOrGo(AppRoutes.members),
    );
  }
}

/// A member's ID card with renewal and sharing. Also used as the detail pane
/// beside the list on tablets, where it has no back link.
class MemberCardView extends ConsumerWidget {
  const MemberCardView({
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
    final l10n = context.l10n;
    final member = ref.watch(memberProvider(memberId));
    final temple = ref.watch(currentTempleProvider);

    return AsyncValueView(
      value: member,
      onRetry: () => ref.invalidate(membersProvider),
      data: (member) {
        if (member == null || temple == null) {
          return AppPage(
            backLabel: backLabel,
            onBack: onBack,
            child: MessageView(message: l10n.cardNotFound),
          );
        }
        return _CardPage(
          member: member,
          temple: temple,
          backLabel: backLabel,
          onBack: onBack,
        );
      },
    );
  }
}

class _CardPage extends ConsumerWidget {
  const _CardPage({
    required this.member,
    required this.temple,
    this.backLabel,
    this.onBack,
  });

  final Member member;
  final Temple temple;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = member.statusOn(ref.watch(todayProvider));
    final number = member.number;
    final outbox = ref.read(outboxActionsProvider);

    Future<void> share() async {
      final sent = await showSendPreview(
        context,
        OutgoingMessage(
          channel: DeliveryChannel.whatsApp,
          recipient: '${member.nameEn} · ${member.phone}',
          body: l10n.msgCardBody(firstNameOf(member.nameEn), temple.nameEn),
          attachment: l10n.msgCardAttachment(number),
        ),
      );
      if (sent) ref.toast(l10n.toastSentWhatsApp);
    }

    Future<void> renew() async {
      final result = await ref.read(membersProvider.notifier).renew(member.id);
      final expiry = result.valueOrNull?.expiresOn;
      if (expiry != null) ref.toast(l10n.toastRenewed(Formats.date(expiry)));
    }

    return AppPage(
      backLabel: backLabel,
      onBack: onBack,
      padding: EdgeInsets.fromLTRB(20, backLabel == null ? 20 : 0, 20, 16),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: l10n.cardShare,
            icon: AppIcons.share,
            onPressed: share,
          ),
          const SizedBox(height: 10),
          EqualRow(
            children: [
              SecondaryButton(
                label: l10n.commonPrint,
                fontSize: 16,
                onPressed: () async {
                  if (await outbox.printDocument(number)) {
                    ref.toast(l10n.toastPrinted);
                  }
                },
              ),
              SecondaryButton(
                label: l10n.cardAddToWallet,
                fontSize: 16,
                onPressed: () async {
                  if (await outbox.addToWallet(number)) {
                    ref.toast(l10n.toastWallet);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      child: Column(
        children: [
          if (status != MembershipStatus.active) ...[
            _RenewBanner(member: member, status: status, onRenew: renew),
            const SizedBox(height: 16),
          ],
          MembershipCard(member: member, temple: temple),
        ],
      ),
    );
  }
}

/// Prompts a renewal when a membership has lapsed or is about to.
class _RenewBanner extends StatelessWidget {
  const _RenewBanner({
    required this.member,
    required this.status,
    required this.onRenew,
  });

  final Member member;
  final MembershipStatus status;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final l10n = context.l10n;
    final (background, foreground) = status == MembershipStatus.expired
        ? (AppPalette.dangerBg, AppPalette.dangerFg)
        : (AppPalette.warningBg, AppPalette.warningFg);
    final expiry = member.expiresOn;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconLabel(
                  icon: status.icon,
                  label: status.label(l10n),
                  style: type.sans(
                    16,
                    weight: FontWeight.w700,
                    color: foreground,
                    height: 1.3,
                  ),
                ),
                if (expiry != null)
                  Text(
                    l10n.cardValidUntilDate(Formats.date(expiry)),
                    style: type.sans(15, color: foreground, height: 1.4),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 148,
            child: PrimaryButton(
              label: l10n.cardRenew,
              onPressed: onRenew,
              minHeight: 52,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
