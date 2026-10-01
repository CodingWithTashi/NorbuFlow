import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../outbox/presentation/outbox_actions.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/offering.dart';
import '../view_models/offering_providers.dart';

/// The names to be read at each upcoming ceremony, in large print for the
/// Geshe. Fed by Puja requests recorded at the front desk.
class PrayerListsScreen extends ConsumerWidget {
  const PrayerListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lists = ref.watch(prayerListsProvider);
    final signatory = ref.watch(currentTempleProvider)?.signatory ?? '';

    return AppPage(
      backLabel: l10n.navHome,
      onBack: () => context.popOrGo(AppRoutes.home),
      bottom: PrimaryButton(
        label: l10n.prayersPrint,
        onPressed: () async {
          final printed = await ref
              .read(outboxActionsProvider)
              .printDocument(l10n.prayersTitle);
          if (printed) ref.toast(l10n.toastPrinted);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: l10n.prayersTitle,
            subtitle: l10n.prayersSubtitle(signatory),
          ),
          const SizedBox(height: 16),
          AsyncValueView(
            value: lists,
            onRetry: () => ref.invalidate(prayerListsProvider),
            data: (lists) => lists.isEmpty
                ? MessageView(message: l10n.prayersEmpty)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, list) in lists.indexed) ...[
                        if (index > 0) const SizedBox(height: 16),
                        _PrayerListCard(list: list),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A printable sheet: light paper in every theme, names at reading size.
class _PrayerListCard extends StatelessWidget {
  const _PrayerListCard({required this.list});

  final PrayerList list;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final l10n = context.l10n;
    const muted = AppPalette.paperInkMuted;

    Widget names(String heading, List<String> names) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading,
          style: type.sans(
            14,
            weight: FontWeight.w700,
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        for (final name in names)
          Text(
            name,
            style: type.sans(21, color: AppPalette.paperInk, height: 1.85),
          ),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.gold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: AppPalette.parchment,
              border: Border(bottom: BorderSide(color: AppPalette.paperLine)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.ceremony.nameEn,
                  style: type.serif(21, color: AppPalette.paperInk),
                ),
                Text(
                  list.ceremony.nameBo,
                  style: type.tibetan(19, color: AppPalette.paperInkSoft),
                ),
                Text(
                  Formats.dayTitle(list.date),
                  style: type.sans(15, color: muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                names(l10n.prayersLivingCount(list.living.length), list.living),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 10),
                  child: Divider(height: 1, color: AppPalette.paperLine),
                ),
                names(
                  l10n.prayersPassedCount(list.deceased.length),
                  list.deceased,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
