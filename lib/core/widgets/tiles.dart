import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'decor.dart';

/// A large tile for "what do you want to do" grids (Home, Offerings).
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.minHeight = 150,
    this.chipSize = 48,
    this.titleLines = 2,
  });

  final AppIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double minHeight;
  final double chipSize;

  /// Lines reserved for the title so tiles in a row line up.
  final int titleLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconChip(
                  size: chipSize,
                  radius: chipSize >= 48 ? 14 : 12,
                  child: AppIcon(
                    icon,
                    size: chipSize >= 48 ? 26 : 24,
                    color: colors.accentText,
                  ),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.textScalerOf(context).scale(17) *
                        1.3 *
                        titleLines,
                  ),
                  child: Text(
                    title,
                    maxLines: titleLines + 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.sans(17, weight: FontWeight.w700, height: 1.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.sans(14, color: colors.inkMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded container that stacks rows with hairline dividers between them.
class GroupedCard extends StatelessWidget {
  const GroupedCard({super.key, required this.children, this.background});

  final List<Widget> children;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background ?? colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) Divider(height: 1, thickness: 1, color: colors.line),
            child,
          ],
        ],
      ),
    );
  }
}

/// One tappable row: optional leading widget, title, description, trailing.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.footer,
    this.onTap,
    this.showChevron = false,
    this.minHeight = 72,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Extra content under the title block (pills, progress bars).
  final Widget? footer;
  final VoidCallback? onTap;
  final bool showChevron;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: type.sans(
                          17,
                          weight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: type.sans(
                            14,
                            color: colors.inkMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: 6),
                        footer!,
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                if (showChevron) ...[
                  const SizedBox(width: 8),
                  AppIcon(
                    AppIcons.chevronRight,
                    size: 20,
                    color: colors.inkMuted,
                    strokeWidth: 2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A caption above a value, used in summaries and receipts.
class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.type.sans(
            14,
            color: context.colors.inkMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.type.sans(17, weight: FontWeight.w500, height: 1.7),
        ),
      ],
    );
  }
}

/// A horizontal bar showing [fraction] of its track.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 10,
    this.radius = 5,
  });

  final double fraction;
  final Color color;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        color: context.colors.card,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0, 1).toDouble(),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      ),
    );
  }
}
