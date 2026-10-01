import 'package:flutter/material.dart';

import '../models/photo_source.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Renders a [PhotoSource] filling its box.
class PhotoImage extends StatelessWidget {
  const PhotoImage(this.photo, {super.key});

  final PhotoSource photo;

  @override
  Widget build(BuildContext context) {
    return switch (photo) {
      MemoryPhoto(:final bytes) => Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
      NetworkPhoto(:final url) => Image.network(url, fit: BoxFit.cover),
    };
  }
}

/// A person: their photo if there is one, otherwise their initials, inside a
/// gold ring.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.photo,
    this.size = 56,
    this.background,
    this.foreground,
    this.ringColor = AppPalette.gold,
    this.ringWidth = 1.5,
  });

  final String name;
  final PhotoSource? photo;
  final double size;
  final Color? background;
  final Color? foreground;
  final Color ringColor;
  final double ringWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? colors.card,
        border: Border.all(
          color: ringColor,
          width: ringWidth,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: photo != null
          ? SizedBox.expand(child: PhotoImage(photo!))
          : Text(
              initialsOf(name),
              textScaler: TextScaler.noScaling,
              style: context.type.serif(
                size * 0.34,
                weight: FontWeight.w600,
                color: foreground ?? colors.accentText,
                height: 1,
              ),
            ),
    );
  }
}

/// A temple's round badge: its logo, or its monogram on the accent colour.
class TempleBadge extends StatelessWidget {
  const TempleBadge({
    super.key,
    required this.monogram,
    this.logo,
    this.size = 44,
    this.background,
  });

  final String monogram;
  final PhotoSource? logo;
  final double size;

  /// Defaults to a translucent shade, for badges that sit on the accent.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? Colors.black.withValues(alpha: 0.15),
        border: Border.all(color: AppPalette.gold, width: 2),
      ),
      child: logo != null
          ? SizedBox.expand(child: PhotoImage(logo!))
          : Text(
              monogram,
              textScaler: TextScaler.noScaling,
              style: context.type.serif(
                size * 0.36,
                color: AppPalette.goldSoft,
                height: 1,
              ),
            ),
    );
  }
}
