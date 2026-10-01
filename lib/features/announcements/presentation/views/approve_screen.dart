import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../domain/announcement.dart';
import '../view_models/announcement_view_model.dart';

/// The Geshe's review queue: approve an announcement or send it back.
class ApproveScreen extends ConsumerWidget {
  const ApproveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pending = ref.watch(approvalsProvider);
    final viewModel = ref.read(approvalsProvider.notifier);
    final waiting = pending.value?.length;

    return AppPage(
      backLabel: l10n.navHome,
      onBack: () => context.popOrGo(AppRoutes.home),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: l10n.approveTitle,
            subtitle: switch (waiting) {
              null => null,
              0 => l10n.approveAllDone,
              _ => l10n.approveWaiting(waiting),
            },
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: pending,
            onRetry: () => ref.invalidate(approvalsProvider),
            data: (items) => items.isEmpty
                ? const _NothingWaiting()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, item) in items.indexed) ...[
                        if (index > 0) const SizedBox(height: 14),
                        _PendingCard(
                          item: item,
                          onApprove: () async {
                            if (await viewModel.approve(item.id)) {
                              ref.toast(
                                l10n.toastApproved(firstNameOf(item.author)),
                              );
                            }
                          },
                          onRequestChanges: () async {
                            if (await viewModel.requestChanges(item.id)) {
                              ref.toast(
                                l10n.toastSentBack(firstNameOf(item.author)),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.item,
    required this.onApprove,
    required this.onRequestChanges,
  });

  final PendingAnnouncement item;
  final VoidCallback onApprove;
  final VoidCallback onRequestChanges;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill(
              label: item.templateName,
              tone: PillTone.plain,
              height: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(item.title, style: type.serif(20)),
          const SizedBox(height: 10),
          Text(
            l10n.approveMeta(item.when, item.author, item.audience),
            style: type.sans(15, color: colors.inkMuted),
          ),
          const SizedBox(height: 10),
          Text(item.details, style: type.sans(16, height: 1.55)),
          const SizedBox(height: 14),
          EqualRow(
            children: [
              PrimaryButton(
                label: l10n.approveYes,
                icon: AppIcons.check,
                onPressed: onApprove,
                minHeight: 56,
                fontSize: 16,
              ),
              SecondaryButton(
                label: l10n.approveAskChanges,
                onPressed: onRequestChanges,
                fontSize: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NothingWaiting extends StatelessWidget {
  const _NothingWaiting();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.gold, width: 1.5),
            ),
            child: AppIcon(
              AppIcons.check,
              size: 40,
              color: colors.success,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.approveEmptyTitle,
            textAlign: TextAlign.center,
            style: type.serif(20),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.approveEmptyBody,
            textAlign: TextAlign.center,
            style: type.sans(16, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}
