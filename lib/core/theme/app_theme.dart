import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'accent_preset.dart';
import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  /// Extra text scale for Tibetan, whose glyph stacks read small at Latin
  /// sizes, and for Simple Mode.
  static const tibetanTextScale = 1.16;
  static const simpleModeTextScale = 1.18;

  static const fieldRadius = BorderRadius.all(Radius.circular(14));

  static ThemeData build({
    required Brightness brightness,
    required AccentPreset accent,
    required bool tibetan,
  }) {
    final colors = AppColors.resolve(brightness: brightness, accent: accent);
    final type = AppTypography(
      ink: colors.ink,
      lineHeight: tibetan
          ? AppTypography.tibetanLineHeight
          : AppTypography.latinLineHeight,
    );

    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          onPrimary: Colors.white,
          secondary: AppPalette.amber,
          onSecondary: AppPalette.espresso,
          surface: colors.background,
          onSurface: colors.ink,
          onSurfaceVariant: colors.inkMuted,
          error: colors.error,
          outline: colors.line,
          outlineVariant: colors.line,
        );

    OutlineInputBorder border(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      fontFamily: AppFonts.sans,
      fontFamilyFallback: const [AppFonts.tibetan],
      splashFactory: InkSparkle.splashFactory,
      dividerColor: colors.line,
      textTheme: TextTheme(
        bodyLarge: type.sans(18),
        bodyMedium: type.sans(17),
        bodySmall: type.sans(15, color: colors.inkMuted),
        titleLarge: type.serif(26),
        titleMedium: type.sans(17, weight: FontWeight.w700),
        labelLarge: type.button,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accentText,
        selectionColor: colors.accentText.withValues(alpha: 0.25),
        selectionHandleColor: colors.accentText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: type.sans(18, color: AppPalette.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: border(colors.line),
        enabledBorder: border(colors.line),
        focusedBorder: border(colors.accentText),
        errorBorder: border(colors.error),
        focusedErrorBorder: border(colors.error),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accentText,
        thumbColor: colors.accentText,
        inactiveTrackColor: colors.line,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentText,
      ),
      extensions: [colors, type],
    );
  }
}

extension ThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppTypography get type => Theme.of(this).extension<AppTypography>()!;
  AppLocalizations get l10n => AppLocalizations.of(this);
}
