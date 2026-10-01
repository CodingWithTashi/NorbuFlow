import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

const _radius = BorderRadius.all(Radius.circular(14));

/// The main action of a screen: one per screen, full width, accent filled.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.subdued = false,
    this.minHeight = 60,
    this.fontSize = 18,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconData? icon;

  /// Shows a spinner and ignores taps while a command is running.
  final bool busy;

  /// Greyed out but still tappable, so a tap can explain what is missing.
  final bool subdued;
  final double minHeight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = subdued ? AppPalette.muted : colors.accent;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: background,
        disabledBackgroundColor: background.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        overlayColor: colors.accentPressed,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
        textStyle: context.type.button.copyWith(fontSize: fontSize),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : _ButtonLabel(label: label, icon: icon, iconColor: Colors.white),
    );
  }
}

/// A supporting action: amber outline on the page background.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.minHeight = 56,
    this.fontSize = 17,
    this.expand = true,
    this.pill = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconData? icon;
  final bool busy;
  final double minHeight;
  final double fontSize;

  /// Fill the available width; otherwise hug the label.
  final bool expand;

  /// Fully rounded ends, used for small inline actions.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: expand ? Size.fromHeight(minHeight) : Size(0, minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        foregroundColor: colors.ink,
        disabledForegroundColor: colors.inkMuted,
        side: const BorderSide(color: AppPalette.amber, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: pill ? BorderRadius.circular(minHeight / 2) : _radius,
        ),
        textStyle: context.type.sans(
          fontSize,
          weight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      child: _ButtonLabel(
        label: label,
        icon: icon,
        iconColor: colors.accentText,
      ),
    );
  }
}

/// A quiet action: accent-coloured text with no container.
class LinkButton extends StatelessWidget {
  const LinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.minHeight = 56,
    this.fontSize = 17,
    this.destructive = false,
    this.underline = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double minHeight;
  final double fontSize;
  final bool destructive;
  final bool underline;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? colors.error : colors.accentText;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: expand ? Size.fromHeight(minHeight) : Size(48, minHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: color,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
        textStyle: context.type.sans(
          fontSize,
          weight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: underline
            ? TextStyle(
                decoration: TextDecoration.underline,
                decorationColor: color,
              )
            : null,
      ),
    );
  }
}

/// Dashed-outline shortcut that stands in for something the fake backend
/// cannot do. Only shown in demo mode.
class DemoButton extends StatelessWidget {
  const DemoButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: colors.line),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: colors.inkMuted,
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: context.type.sans(15, height: 1.3),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon, required this.iconColor});

  final String label;
  final AppIconData? icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(icon!, size: 22, color: iconColor, strokeWidth: 2),
        const SizedBox(width: 10),
        Flexible(child: text),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.75),
          const Radius.circular(14),
        ),
      );
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash + gap) {
        canvas.drawPath(metric.extractPath(at, at + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
