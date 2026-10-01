import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/tiles.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../temple/presentation/view_models/team_view_model.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../../temple/presentation/views/temple_switcher.dart';
import '../view_models/preferences_view_model.dart';
import '../widgets/language_toggle.dart';

/// The More tab: language and display preferences, this temple's team and
/// settings, and sign out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final preferences = ref.watch(preferencesProvider);
    final preferencesViewModel = ref.read(preferencesProvider.notifier);
    final temple = ref.watch(currentTempleProvider);
    final teamSize = ref.watch(teamProvider).value?.length;
    final canManage = ref.watch(myRoleProvider).canManageTemple;

    Widget rowIcon(AppIconData icon) => IconChip(
      background: colors.card,
      child: AppIcon(icon, color: colors.accentText),
    );

    return AppPage(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.settingsTitle, style: type.screenTitle),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.settingsLanguage,
            style: type.sans(17, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: LanguageToggle(compactLabels: false),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsChineseLater,
            style: type.sans(14, color: colors.inkMuted),
          ),
          const SizedBox(height: 20),
          OverlineLabel(l10n.settingsDisplay),
          const SizedBox(height: 14),
          _ToggleTile(
            title: l10n.settingsDarkMode,
            subtitle: l10n.settingsDarkModeSub,
            value: preferences.darkMode,
            onChanged: preferencesViewModel.setDarkMode,
          ),
          const SizedBox(height: 14),
          _ToggleTile(
            title: l10n.settingsSimpleMode,
            subtitle: l10n.settingsSimpleModeSub,
            value: preferences.simpleMode,
            onChanged: preferencesViewModel.setSimpleMode,
          ),
          const SizedBox(height: 20),
          OverlineLabel(l10n.settingsThisTemple),
          const SizedBox(height: 14),
          GroupedCard(
            children: [
              ListRow(
                leading: rowIcon(AppIcons.members),
                title: l10n.settingsTeamRow,
                subtitle: teamSize == null
                    ? null
                    : l10n.settingsTeamRowSub(teamSize),
                minHeight: 76,
                showChevron: true,
                onTap: () => context.go(AppRoutes.team),
              ),
              ListRow(
                leading: rowIcon(AppIcons.sliders),
                title: l10n.settingsTempleRow,
                subtitle: l10n.settingsTempleRowSub,
                minHeight: 76,
                showChevron: true,
                onTap: () {
                  if (canManage) {
                    context.go(AppRoutes.templeSettings);
                  } else {
                    ref
                        .read(appMessengerProvider.notifier)
                        .showFailure(
                          const PermissionFailure(
                            reason: PermissionReason.adminOnlySettings,
                          ),
                        );
                  }
                },
              ),
              ListRow(
                leading: rowIcon(AppIcons.swap),
                title: l10n.settingsSwitchRow,
                subtitle: temple?.url,
                minHeight: 76,
                showChevron: true,
                onTap: () => showTempleSwitcher(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SecondaryButton(
            label: l10n.settingsSignOut,
            onPressed: ref.read(authViewModelProvider.notifier).signOut,
          ),
        ],
      ),
    );
  }
}

/// A preference that is either on or off, with the state spelled out in
/// words beside the switch.
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    return Semantics(
      toggled: value,
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: type.sans(17, weight: FontWeight.w600),
                        ),
                        Text(
                          subtitle,
                          style: type.sans(14, color: colors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    value ? l10n.commonOn : l10n.commonOff,
                    style: type.sans(15, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 52,
                    height: 32,
                    padding: const EdgeInsets.all(3),
                    alignment: value
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: value ? colors.success : AppPalette.switchOff,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.knobShadow,
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
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
