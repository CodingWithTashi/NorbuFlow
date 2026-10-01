import 'package:flutter/material.dart';

abstract final class AppFonts {
  static const sans = 'AtkinsonHyperlegibleNext';
  static const serif = 'SourceSerif4';
  static const tibetan = 'NotoSerifTibetan';
}

/// Builds every text style in the app, so font families, the Tibetan
/// fallback and line heights are decided once.
///
/// Sizes are design sizes; scaling for Tibetan and Simple Mode is applied
/// app-wide through `MediaQuery.textScaler` (see `NorbuFlowApp`).
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({required this.ink, required this.lineHeight});

  /// Default text colour.
  final Color ink;

  /// Body line height: Tibetan stacks need noticeably more room.
  final double lineHeight;

  static const tibetanLineHeight = 1.85;
  static const latinLineHeight = 1.45;

  /// The tightest line Tibetan can be set on before its stacked glyphs
  /// collide with the lines above and below.
  static const _minTibetanLineHeight = 1.7;

  bool get _tibetan => lineHeight > 1.5;

  /// Callers pass line heights tuned for Latin text. In the Tibetan interface
  /// those are raised to a height the script can be read at, so no screen
  /// has to special-case the language.
  double _lineHeightFor(double? requested) {
    if (requested == null) return lineHeight;
    if (!_tibetan || requested >= _minTibetanLineHeight) return requested;
    return _minTibetanLineHeight;
  }

  /// Body and UI text.
  TextStyle sans(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: AppFonts.sans,
      fontFamilyFallback: const [AppFonts.tibetan],
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      height: _lineHeightFor(height),
      letterSpacing: letterSpacing,
    );
  }

  /// Titles, names and amounts.
  TextStyle serif(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
    FontStyle? style,
  }) {
    return TextStyle(
      fontFamily: AppFonts.serif,
      fontFamilyFallback: const [AppFonts.tibetan],
      fontSize: size,
      fontWeight: weight,
      fontStyle: style,
      color: color ?? ink,
      height: _lineHeightFor(height ?? 1.3),
    );
  }

  /// Text that is always Tibetan (a member's or temple's Tibetan name),
  /// whatever the interface language.
  TextStyle tibetan(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: AppFonts.tibetan,
      fontSize: size,
      fontWeight: weight,
      color: color ?? ink,
      height: 1.75,
    );
  }

  TextStyle get screenTitle => serif(26, height: 1.25);
  TextStyle get sectionTitle => sans(17, weight: FontWeight.w700, height: 1.3);
  TextStyle get button => sans(18, weight: FontWeight.w600, height: 1.2);

  /// Small all-caps group heading.
  TextStyle overline(Color color) =>
      sans(14, weight: FontWeight.w700, color: color, letterSpacing: 0.6);

  @override
  AppTypography copyWith({Color? ink, double? lineHeight}) {
    return AppTypography(
      ink: ink ?? this.ink,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) return this;
    return AppTypography(
      ink: Color.lerp(ink, other.ink, t)!,
      lineHeight: t < 0.5 ? lineHeight : other.lineHeight,
    );
  }
}
