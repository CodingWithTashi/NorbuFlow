import 'package:flutter/material.dart';

import 'accent_preset.dart';

/// Colours that are the same in every theme: ornament, status tones and the
/// "paper" used for documents (ID cards, receipts) that always print light.
abstract final class AppPalette {
  static const gold = Color(0xFFC9A227);
  static const goldSoft = Color(0xFFF3D88A);
  static const amber = Color(0xFFE39B2D);
  static const saffronText = Color(0xFF9A5A12);

  static const cream = Color(0xFFFBF6EC);
  static const parchment = Color(0xFFF3EAD8);
  static const sand = Color(0xFFE6D3B5);
  static const paper = Color(0xFFFFFDF8);
  static const paperLine = Color(0xFFE2D3B6);
  static const paperInk = Color(0xFF2B1B17);
  static const paperInkSoft = Color(0xFF4A3229);
  static const paperInkMuted = Color(0xFF6A4E44);
  static const paperLabel = Color(0xFF7A5B4E);
  static const espresso = Color(0xFF2B1B17);
  static const maroonDeep = Color(0xFF5A1520);

  static const muted = Color(0xFF9A8576);
  static const switchOff = Color(0xFFB5A596);
  static const scrim = Color(0x801E1210);

  /// Dims the part of a photo outside the crop circle.
  static const cropScrim = Color(0x9E1E1210);
  static const knobShadow = Color(0x4D000000);

  /// Printed volunteer plan: a day with no shift, and practice-day notes.
  static const planNoShift = Color(0xFFF1ECE3);
  static const planPracticeInk = Color(0xFF7D5F10);

  static const successBg = Color(0xFFE3F0E7);
  static const successFg = Color(0xFF1E5C3A);
  static const success = Color(0xFF2E7D4F);
  static const warningBg = Color(0xFFFBEBD0);
  static const warningFg = Color(0xFF7A4A0B);
  static const warningInk = Color(0xFF5A3608);
  static const dangerBg = Color(0xFFF7DEDB);
  static const dangerFg = Color(0xFF8E1D17);
  static const danger = Color(0xFFB3261E);
  static const neutralBg = Color(0xFFE7E1D8);
  static const neutralFg = Color(0xFF5C4E45);

  /// Prayer-flag order: blue, white, red, green, yellow.
  static const flagBlue = Color(0xFF1F5FA8);
  static const flagWhite = Color(0xFFFFFFFF);
  static const flagRed = Color(0xFFB3261E);
  static const flagGreen = Color(0xFF2E7D4F);
  static const flagYellow = Color(0xFFE8B931);

  static const whatsAppBubble = Color(0xFFDCF8C6);
  static const whatsAppPreview = Color(0xFFDDF3D8);
  static const whatsAppWallpaper = Color(0xFFECE5DD);
  static const whatsAppInk = Color(0xFF1C1C1C);
  static const whatsAppInkMuted = Color(0xFF555555);
}

extension AccentPresetColors on AccentPreset {
  Color get color => switch (this) {
    AccentPreset.maroon => const Color(0xFF7A1F2B),
    AccentPreset.saffron => const Color(0xFF9A5A12),
    AccentPreset.lapisBlue => const Color(0xFF1F4E8C),
    AccentPreset.jadeGreen => const Color(0xFF2E6B4F),
    AccentPreset.turquoise => const Color(0xFF17676B),
    AccentPreset.deepGold => const Color(0xFF7D5F10),
  };

  /// Darker shade for pressed states.
  Color get pressed => switch (this) {
    AccentPreset.maroon => const Color(0xFF5A1520),
    AccentPreset.saffron => const Color(0xFF74430D),
    AccentPreset.lapisBlue => const Color(0xFF163A69),
    AccentPreset.jadeGreen => const Color(0xFF21503A),
    AccentPreset.turquoise => const Color(0xFF104C4F),
    AccentPreset.deepGold => const Color(0xFF5C460B),
  };
}

/// Colours that change with light/dark mode and the temple's accent.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.accentPressed,
    required this.accentText,
    required this.background,
    required this.card,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.error,
    required this.success,
  });

  factory AppColors.resolve({
    required Brightness brightness,
    required AccentPreset accent,
  }) {
    final dark = brightness == Brightness.dark;
    return AppColors(
      accent: accent.color,
      accentPressed: accent.pressed,
      // The accent is too dark to read on a dark background.
      accentText: dark ? const Color(0xFFEBC07A) : accent.color,
      background: dark ? const Color(0xFF1E1210) : AppPalette.cream,
      card: dark ? const Color(0xFF2E1D19) : AppPalette.parchment,
      surface: dark ? const Color(0xFF271815) : AppPalette.paper,
      ink: dark ? const Color(0xFFF7EEDF) : AppPalette.espresso,
      inkMuted: dark ? const Color(0xFFD2BEA8) : AppPalette.paperInkMuted,
      line: dark ? const Color(0xFF4A3128) : AppPalette.paperLine,
      error: dark ? const Color(0xFFF2867D) : AppPalette.danger,
      success: dark ? const Color(0xFF7CC79A) : AppPalette.success,
    );
  }

  /// Fills: buttons, headers, selected chips. Always pairs with white text.
  final Color accent;
  final Color accentPressed;

  /// Accent used for text and icons on [background].
  final Color accentText;
  final Color background;
  final Color card;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color error;
  final Color success;

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentPressed,
    Color? accentText,
    Color? background,
    Color? card,
    Color? surface,
    Color? ink,
    Color? inkMuted,
    Color? line,
    Color? error,
    Color? success,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      accentPressed: accentPressed ?? this.accentPressed,
      accentText: accentText ?? this.accentText,
      background: background ?? this.background,
      card: card ?? this.card,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      line: line ?? this.line,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}
