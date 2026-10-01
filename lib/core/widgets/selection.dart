import 'package:flutter/material.dart';

import '../layout/responsive.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'decor.dart';

/// A tappable card whose border and fill show whether it is chosen.
class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.minHeight = 64,
    this.radius = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.dimmed = false,
    this.filledWhenSelected = false,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;
  final double minHeight;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Shown at reduced opacity (e.g. a volunteer who is away) but still
  /// tappable, so a tap can explain why.
  final bool dimmed;

  /// Fill with the accent colour instead of the card tint.
  final bool filledWhenSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = !selected
        ? colors.surface
        : (filledWhenSelected ? colors.accent : colors.card);
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: selected ? colors.accent : colors.line,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio indicator used inside option tiles.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.accentText;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
        ),
      ),
    );
  }
}

/// Checkbox indicator used inside multi-select tiles.
class CheckSquare extends StatelessWidget {
  const CheckSquare({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.accentText, width: 2),
      ),
      child: selected
          ? const AppIcon(
              AppIcons.check,
              size: 18,
              color: Colors.white,
              strokeWidth: 3,
            )
          : null,
    );
  }
}

enum OptionIndicator { radio, checkbox, trailingCheck }

/// A full-width option row: title, optional description, and an indicator.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.indicator = OptionIndicator.radio,
    this.minHeight = 68,
    this.dimmed = false,
    this.titleWeight = FontWeight.w700,
  });

  final String title;
  final String? subtitle;

  /// Replaces [subtitle] when the description needs custom styling.
  final Widget? subtitleWidget;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;
  final OptionIndicator indicator;
  final double minHeight;
  final bool dimmed;
  final FontWeight titleWeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      minHeight: minHeight,
      dimmed: dimmed,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          if (indicator == OptionIndicator.radio) ...[
            RadioDot(selected: selected),
            const SizedBox(width: 14),
          ] else if (indicator == OptionIndicator.checkbox) ...[
            CheckSquare(selected: selected),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: type.sans(17, weight: titleWeight, height: 1.3),
                ),
                if (subtitleWidget != null)
                  subtitleWidget!
                else if (subtitle != null)
                  Text(
                    subtitle!,
                    style: type.sans(14, color: colors.inkMuted, height: 1.45),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (indicator == OptionIndicator.trailingCheck) ...[
            const SizedBox(width: 10),
            SizedBox.square(
              dimension: 22,
              child: selected
                  ? AppIcon(
                      AppIcons.check,
                      size: 22,
                      color: colors.accentText,
                      strokeWidth: 2.4,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// A rounded chip for picking one of a handful of short labels.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minHeight = 52,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      minHeight: minHeight,
      radius: minHeight / 2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _TickedLabel(
              label: label,
              ticked: selected,
              style: context.type.sans(
                16,
                weight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A centred choice button used in two-column grids (payment methods).
class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.minHeight = 60,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      minHeight: minHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Center(
        child: _TickedLabel(
          label: label,
          ticked: selected,
          textAlign: TextAlign.center,
          style: context.type.sans(17, weight: FontWeight.w600, height: 1.3),
        ),
      ),
    );
  }
}

/// A label that gains a leading tick when chosen, so selection is not
/// signalled by colour alone.
class _TickedLabel extends StatelessWidget {
  const _TickedLabel({
    required this.label,
    required this.ticked,
    required this.style,
    this.textAlign,
  });

  final String label;
  final bool ticked;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ticked
        ? IconLabel(
            icon: AppIcons.check,
            label: label,
            style: style,
            textAlign: textAlign,
          )
        : Text(label, style: style, textAlign: textAlign);
  }
}

/// A row of equal-width preset amounts; the chosen one is filled.
class AmountPicker extends StatelessWidget {
  const AmountPicker({
    super.key,
    required this.amounts,
    required this.selected,
    required this.onChanged,
    required this.format,
  });

  final List<int> amounts;
  final int selected;
  final ValueChanged<int> onChanged;
  final String Function(int amount) format;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EqualRow(
      gap: 8,
      children: [
        for (final amount in amounts)
          SelectableCard(
            selected: amount == selected,
            filledWhenSelected: true,
            onTap: () => onChanged(amount),
            minHeight: 60,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Center(
              child: Text(
                format(amount),
                style: context.type.serif(
                  18,
                  color: amount == selected ? Colors.white : colors.ink,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A segmented control with rounded ends (language, plan mode, preview).
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    this.minHeight = 48,
    this.fontSize = 16,
  });

  /// Value → label, in display order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Share the available width equally instead of hugging the labels.
  final bool expand;
  final double minHeight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget segment(T value, String label) {
      final active = value == selected;
      final button = Semantics(
        selected: active,
        button: true,
        child: Material(
          color: active ? colors.accent : Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(value),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight, minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: context.type.sans(
                  fontSize,
                  weight: FontWeight.w600,
                  color: active ? Colors.white : colors.ink,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      );
      return expand ? Expanded(child: button) : button;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      // The border is painted over the segments so the fill reaches the edge.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.line, width: 1.5),
      ),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in segments.entries)
              segment(entry.key, entry.value),
          ],
        ),
      ),
    );
  }
}
