import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/feedback/dialogs.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/selection.dart';
import '../../domain/temple.dart';
import '../view_models/temple_session.dart';
import '../widgets/add_temple_locked.dart';

/// Lets the person pick another temple, confirms the switch, then moves
/// them to that temple's Home.
Future<void> showTempleSwitcher(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final chosen = await showAppSheet<Temple>(
    context: context,
    title: l10n.templeSwitchSheetTitle,
    builder: (_) => const _TempleChoices(),
  );
  if (chosen == null || !context.mounted) return;
  if (chosen.id == ref.read(currentTempleIdProvider)) return;

  final confirmed = await showConfirmDialog(
    context: context,
    title: l10n.templeSwitchConfirmTitle(chosen.nameEn),
    message: l10n.templeSwitchConfirmBody(chosen.nameEn),
    confirmLabel: l10n.templeSwitchConfirmYes,
    cancelLabel: l10n.templeSwitchConfirmNo,
  );
  if (!confirmed || !context.mounted) return;

  ref.read(currentTempleIdProvider.notifier).select(chosen.id);
  context.go(AppRoutes.home);
  ref.toast(l10n.toastTempleSwitched(chosen.nameEn));
}

class _TempleChoices extends ConsumerWidget {
  const _TempleChoices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final currentId = ref.watch(currentTempleIdProvider);
    final memberships = ref.watch(templesProvider).value ?? const [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, membership) in memberships.indexed) ...[
          if (index > 0) const SizedBox(height: 14),
          SelectableCard(
            // The border marks where you are, not a pending choice.
            selected: false,
            radius: 16,
            minHeight: 76,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () => Navigator.of(context).pop(membership.temple),
            child: Row(
              children: [
                TempleBadge(
                  monogram: membership.temple.monogram,
                  logo: membership.temple.logo,
                  size: 48,
                  background: membership.temple.accent.color,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        membership.temple.nameEn,
                        style: type.sans(
                          17,
                          weight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      if (_caption(membership.temple) case final caption?)
                        Text(
                          caption,
                          style: type.sans(
                            14,
                            color: colors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                if (membership.temple.id == currentId) ...[
                  const SizedBox(width: 8),
                  IconLabel(
                    icon: AppIcons.check,
                    label: context.l10n.templeYouAreHere,
                    style: type.sans(
                      14,
                      weight: FontWeight.w600,
                      color: colors.success,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        const AddTempleLocked(radius: 16),
      ],
    );
  }

  /// The temple's web address, or failing that what it says about itself.
  static String? _caption(Temple temple) {
    if (temple.url.isNotEmpty) return temple.url;
    return temple.tradition.isEmpty ? null : temple.tradition;
  }
}
