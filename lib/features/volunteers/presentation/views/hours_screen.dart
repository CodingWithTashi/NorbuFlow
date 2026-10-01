import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/tiles.dart';
import '../view_models/calendar_view_model.dart';
import '../view_models/letter_view_model.dart';

/// Hours given by each volunteer this year. Tapping someone starts a letter
/// for them.
class HoursScreen extends ConsumerWidget {
  const HoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final today = ref.watch(todayProvider);
    final summary = ref.watch(hoursSummaryProvider);
    final top = summary.value?.ranked.firstOrNull;

    return AppPage(
      backLabel: l10n.navHome,
      onBack: () => context.popOrGo(AppRoutes.home),
      bottom: PrimaryButton(
        label: l10n.hoursWriteThanks,
        onPressed: () => context.go(
          top == null ? AppRoutes.letter : AppRoutes.letterFor(top.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: l10n.hoursTitle,
            subtitle: l10n.hoursPeriod(Formats.monthName(today), today.year),
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: summary,
            onRetry: () => ref.invalidate(volunteersProvider),
            data: (summary) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${summary.total}',
                        style: type.serif(44, height: 1),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.hoursTotalLabel(summary.ranked.length),
                          style: type.sans(17, color: colors.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GroupedCard(
                  children: [
                    for (final volunteer in summary.ranked)
                      ListRow(
                        title: volunteer.name,
                        minHeight: 76,
                        onTap: () =>
                            context.go(AppRoutes.letterFor(volunteer.id)),
                        trailing: Text(
                          l10n.hoursValue(volunteer.hoursThisYear),
                          style: type.sans(17, weight: FontWeight.w700),
                        ),
                        footer: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProgressBar(
                              fraction: summary.top == 0
                                  ? 0
                                  : volunteer.hoursThisYear / summary.top,
                              color: AppPalette.amber,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.hoursRowMeta(
                                volunteer.duties,
                                volunteer.sinceYear,
                              ),
                              style: type.sans(14, color: colors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
