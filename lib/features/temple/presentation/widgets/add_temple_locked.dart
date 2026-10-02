import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/decor.dart';

/// "Add a temple", shown locked. Temples are registered by NorbuFlow, not
/// from the app, so tapping it only says so.
class AddTempleLocked extends ConsumerWidget {
  const AddTempleLocked({super.key, this.radius = 20});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.toast(l10n.templesAddLockedBody),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              spacing: 14,
              children: [
                IconChip(
                  size: 48,
                  child: AppIcon(
                    AppIcons.lock,
                    size: 24,
                    color: colors.inkMuted,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.templesAdd,
                        style: type.sans(
                          17,
                          weight: FontWeight.w600,
                          color: colors.inkMuted,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        l10n.templesAddLockedBody,
                        style: type.sans(
                          14,
                          color: colors.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: l10n.templesAddLocked,
                  icon: AppIcons.lock,
                  tone: PillTone.neutral,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
