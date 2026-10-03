import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/avatars.dart';
import '../../core/widgets/decor.dart';
import '../../features/temple/domain/temple.dart';
import '../../features/temple/domain/temple_features.dart';
import '../../features/temple/presentation/temple_labels.dart';
import '../../features/temple/presentation/view_models/temple_session.dart';
import '../../features/temple/presentation/views/temple_switcher.dart';
import '../router/app_routes.dart';

/// The signed-in frame: temple header on top, the sections the temple shows
/// reachable from a tab bar on phones or a side rail on tablets.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;

  /// Path of the screen currently shown, e.g. `/members/add`.
  final String location;

  void _goToTab(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the tab you are on returns to its first screen.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final temple = ref.watch(currentTempleProvider);
    if (temple == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const LoadingView(),
      );
    }

    final windowClass = context.windowClass;
    final compact = windowClass == WindowClass.compact;
    final tabs = _tabs(context, temple.features);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TempleHeader(
              temple: temple,
              onSwitch: () => showTempleSwitcher(context, ref),
            ),
            const PrayerFlagStripe(),
            const _RolePreviewBanner(),
            Expanded(
              child: SafeArea(
                top: false,
                child: compact
                    ? navigationShell
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SideRail(
                            tabs: tabs,
                            currentIndex: navigationShell.currentIndex,
                            onSelect: _goToTab,
                            extended: windowClass == WindowClass.expanded,
                          ),
                          Expanded(child: navigationShell),
                        ],
                      ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: compact && AppRoutes.withTabBar.contains(location)
            ? _BottomTabBar(
                tabs: tabs,
                currentIndex: navigationShell.currentIndex,
                onSelect: _goToTab,
              )
            : null,
      ),
    );
  }

  /// The tabs the temple shows. Each keeps its branch index (see the router).
  List<_Tab> _tabs(BuildContext context, TempleFeatures features) {
    final l10n = context.l10n;
    return [
      _Tab(0, AppIcons.home, l10n.tabHome),
      if (features.shows(TempleTab.members))
        _Tab(1, AppIcons.members, l10n.tabMembers),
      if (features.shows(TempleTab.offerings))
        _Tab(2, AppIcons.bowl, l10n.tabOfferings),
      if (features.shows(TempleTab.calendar))
        _Tab(3, AppIcons.calendar, l10n.tabCalendar),
      _Tab(4, AppIcons.more, l10n.tabMore),
    ];
  }
}

@immutable
class _Tab {
  const _Tab(this.branch, this.icon, this.label);

  final int branch;
  final AppIconData icon;
  final String label;
}

class _TempleHeader extends StatelessWidget {
  const _TempleHeader({required this.temple, required this.onSwitch});

  final Temple temple;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Material(
      color: context.colors.accent,
      child: InkWell(
        onTap: onSwitch,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TempleBadge(monogram: temple.monogram, logo: temple.logo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          temple.nameEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.serif(
                            17,
                            weight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        if (temple.nameBo.isNotEmpty)
                          Text(
                            temple.nameBo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.tibetan(
                              14,
                              color: AppPalette.parchment,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppPalette.gold),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.templeSwitch,
                          style: type.sans(
                            14,
                            weight: FontWeight.w600,
                            color: AppPalette.goldSoft,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const AppIcon(
                          AppIcons.chevronDown,
                          size: 14,
                          color: AppPalette.goldSoft,
                          strokeWidth: 2.4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while an admin previews another role's Home screen.
class _RolePreviewBanner extends ConsumerWidget {
  const _RolePreviewBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(rolePreviewProvider);
    if (role == null) return const SizedBox.shrink();
    final type = context.type;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 10, 8),
      decoration: const BoxDecoration(
        color: AppPalette.warningBg,
        border: Border(bottom: BorderSide(color: AppPalette.amber)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${l10n.previewLabel} ',
                style: const TextStyle(fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: l10n.previewBody(role.label(l10n)),
                    style: const TextStyle(fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              style: type.sans(15, color: AppPalette.warningInk, height: 1.35),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () {
              ref.read(rolePreviewProvider.notifier).exit();
              context.go(AppRoutes.team);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              foregroundColor: AppPalette.warningInk,
              side: const BorderSide(color: AppPalette.saffronText, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: type.sans(15, weight: FontWeight.w700, height: 1.2),
            ),
            child: Text(l10n.previewExit),
          ),
        ],
      ),
    );
  }
}

class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_Tab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A Material (not a DecoratedBox) so tab ink ripples paint on the bar.
    return Material(
      color: colors.surface,
      shape: Border(top: BorderSide(color: colors.line)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _TabButton(
                    tab: tab,
                    selected: tab.branch == currentIndex,
                    onTap: () => onSelect(tab.branch),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.accentText : colors.inkMuted;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: selected ? AppPalette.amber : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            // Hug the content: the Scaffold offers a bottom bar the whole
            // screen height, and it must only take what it needs.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(tab.icon, size: 26, color: color, strokeWidth: 1.9),
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.sans(
                  13,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tablet navigation: icons over labels at medium widths, icons beside
/// labels once there is room.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.extended,
  });

  final List<_Tab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: extended ? 232 : 96,
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(end: BorderSide(color: colors.line)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: EdgeInsets.symmetric(
            vertical: 16,
            horizontal: extended ? 12 : 0,
          ),
          children: [
            for (final tab in tabs)
              extended
                  ? _RailRow(
                      tab: tab,
                      selected: tab.branch == currentIndex,
                      onTap: () => onSelect(tab.branch),
                    )
                  : _RailButton(
                      tab: tab,
                      selected: tab.branch == currentIndex,
                      onTap: () => onSelect(tab.branch),
                    ),
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.accentText : colors.inkMuted;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(
                color: selected ? AppPalette.amber : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(tab.icon, size: 28, color: color, strokeWidth: 1.9),
              const SizedBox(height: 4),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.sans(
                  13,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.accentText : colors.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? colors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    AppIcon(tab.icon, size: 26, color: color, strokeWidth: 1.9),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.sans(
                          16,
                          weight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? colors.ink : colors.inkMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
