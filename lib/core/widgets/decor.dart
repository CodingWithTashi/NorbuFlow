import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// The five prayer-flag colours as a thin band. Purely decorative.
class PrayerFlagStripe extends StatelessWidget {
  const PrayerFlagStripe({
    super.key,
    this.height = 5,
    this.white = AppPalette.flagWhite,
  });

  final double height;

  /// The "white" flag; a cream tone is used where the band sits on white.
  final Color white;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final color in [
              AppPalette.flagBlue,
              white,
              AppPalette.flagRed,
              AppPalette.flagGreen,
              AppPalette.flagYellow,
            ])
              Expanded(child: ColoredBox(color: color)),
          ],
        ),
      ),
    );
  }
}

enum PillTone { success, warning, danger, neutral, plain }

/// Status shown as icon + words on a tinted pill — never colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.height = 26,
    this.fontSize = 13,
  });

  final String label;
  final PillTone tone;

  final AppIconData? icon;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      PillTone.success => (AppPalette.successBg, AppPalette.successFg),
      PillTone.warning => (AppPalette.warningBg, AppPalette.warningFg),
      PillTone.danger => (AppPalette.dangerBg, AppPalette.dangerFg),
      PillTone.neutral => (AppPalette.neutralBg, AppPalette.neutralFg),
      PillTone.plain => (colors.card, colors.ink),
    };
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(height),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(
              icon!,
              size: fontSize + 1,
              color: foreground,
              strokeWidth: 2.6,
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: _style(context, foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _style(BuildContext context, Color color) => context.type.sans(
    fontSize,
    weight: FontWeight.w700,
    color: color,
    height: 1.2,
  );
}

/// A small icon followed by text, e.g. a tick and "Progress saved". The icon
/// tracks the text size, including the reader's text scale.
class IconLabel extends StatelessWidget {
  const IconLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.style,
    this.textAlign,
  });

  final AppIconData icon;
  final String label;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(style.fontSize ?? 16);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: AppIcon(
                icon,
                size: size,
                color: style.color,
                strokeWidth: 2.4,
              ),
            ),
          ),
          TextSpan(text: label),
        ],
      ),
      style: style,
      textAlign: textAlign,
    );
  }
}

/// Rounded icon chip with a hairline gold ring.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.child,
    this.size = 44,
    this.radius = 12,
    this.background,
  });

  final Widget child;
  final double size;
  final double radius;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? context.colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

/// All-caps group heading above a block of settings or fields.
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.type.overline(color ?? context.colors.inkMuted),
    );
  }
}

/// A screen's serif title with an optional muted line beneath it.
class ScreenHeading extends StatelessWidget {
  const ScreenHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: context.type.screenTitle),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: context.type.sans(16, color: context.colors.inkMuted),
          ),
        ],
      ],
    );
  }
}

/// Numbered step heading inside a single-page flow ("2 · Type of letter").
class StepHeading extends StatelessWidget {
  const StepHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: context.type.sectionTitle),
    );
  }
}
