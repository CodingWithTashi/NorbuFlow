import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calendar/tibetan_calendar.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/tiles.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../settings/presentation/view_models/preferences_view_model.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../home_actions.dart';

/// "What would you like to do today?" — a short grid of the tasks the
/// person's role actually performs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final today = ref.watch(todayProvider);
    final tibetan = ref.watch(tibetanCalendarProvider).dayOf(today);
    final role = ref.watch(homeRoleProvider);
    final name = ref.watch(
      authViewModelProvider.select((auth) => auth.user?.displayName ?? ''),
    );

    return AppPage(
      maxWidth: Breakpoints.wideContentMaxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Formats.homeDate(today, locale),
            style: type.sans(15, color: colors.inkMuted),
          ),
          Row(
            children: [
              const AppIcon(AppIcons.diamond, size: 11, color: AppPalette.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.tibetanDate(
                    Formats.digits(tibetan.month, locale),
                    Formats.digits(tibetan.day, locale),
                  ),
                  style: type.sans(14, color: colors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            header: true,
            child: Text(
              l10n.homeGreeting(firstNameOf(name)),
              style: type.serif(28),
            ),
          ),
          const SizedBox(height: 4),
          Text(l10n.homeAsk, style: type.sans(17, color: colors.inkMuted)),
          const SizedBox(height: 18),
          ResponsiveGrid(
            minItemWidth: 164,
            maxColumns: 4,
            children: [
              for (final action in role.homeActions)
                ActionTile(
                  icon: action.icon,
                  title: action.label(l10n),
                  subtitle: action.hint(l10n),
                  onTap: () => action.open(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
