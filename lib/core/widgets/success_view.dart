import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'app_page.dart';
import 'buttons.dart';

/// One way of passing a document on: print, email or WhatsApp.
@immutable
class ShareAction {
  const ShareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
}

/// A row of equal [ShareAction] buttons.
class ShareActionRow extends StatelessWidget {
  const ShareActionRow({super.key, required this.actions, this.filled = false});

  final List<ShareAction> actions;

  /// Accent-filled buttons (as a screen's main actions) instead of tinted.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EqualRow(
      children: [
        for (final action in actions)
          Material(
            color: filled ? colors.accent : colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(filled ? 14 : 16),
              side: filled
                  ? BorderSide.none
                  : BorderSide(color: colors.line, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: action.onTap,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: filled ? 72 : 84),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(
                        action.icon,
                        size: filled ? 24 : 26,
                        color: filled ? Colors.white : colors.accentText,
                      ),
                      SizedBox(height: filled ? 4 : 6),
                      Text(
                        action.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.sans(
                          15,
                          weight: FontWeight.w600,
                          color: filled ? Colors.white : colors.ink,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The confirmation shown when a flow completes.
class SuccessView extends StatelessWidget {
  const SuccessView({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDone,
    this.shareActions = const [],
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onDone;
  final List<ShareAction> shareActions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return AppPage(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(label: primaryLabel, onPressed: onPrimary),
          const SizedBox(height: 6),
          LinkButton(
            label: context.l10n.commonDone,
            onPressed: onDone,
            expand: true,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppPalette.successBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppPalette.success.withValues(alpha: 0.12),
                width: 8,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: const AppIcon(
              AppIcons.check,
              size: 48,
              color: AppPalette.success,
              strokeWidth: 2.4,
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: type.serif(26),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: type.sans(17, color: colors.inkMuted, height: 1.55),
          ),
          if (shareActions.isNotEmpty) ...[
            const SizedBox(height: 24),
            ShareActionRow(actions: shareActions),
          ],
        ],
      ),
    );
  }
}
