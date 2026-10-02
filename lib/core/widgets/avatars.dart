import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/photo_source.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Renders a [PhotoSource] filling its box. A photo from the backend is
/// kept on the device once fetched, so it is downloaded only once.
class PhotoImage extends StatelessWidget {
  const PhotoImage(
    this.photo, {
    super.key,
    this.alignment = Alignment.center,
    this.fallback,
    this.cacheWidth,
  });

  final PhotoSource photo;

  /// Which part of the photo to keep when its shape is not the box's.
  final Alignment alignment;

  /// Shown while a photo is on its way, and in its place if it never comes.
  final Widget? fallback;

  /// Decodes a fetched photo no wider than this, in pixels: a small avatar
  /// does not need the whole picture in memory.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final waiting = fallback ?? const SizedBox.shrink();
    return switch (photo) {
      MemoryPhoto(:final bytes) => Image.memory(
        bytes,
        fit: BoxFit.cover,
        alignment: alignment,
        gaplessPlayback: true,
      ),
      NetworkPhoto(:final url, :final cacheKey) => CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey,
        fit: BoxFit.cover,
        alignment: alignment,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: Duration.zero,
        placeholder: (_, _) => waiting,
        errorWidget: (_, _, _) => waiting,
      ),
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

  /// Sharp on the densest screens the app runs on.
  static const _pixelsPerPoint = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initials = Center(
      child: Text(
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
    return Container(
      width: size,
      height: size,
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
      child: photo == null
          ? initials
          : SizedBox.expand(
              child: PhotoImage(
                photo!,
                // An ID photo is taller than the circle: keep the face.
                alignment: const Alignment(0, -0.6),
                fallback: initials,
                cacheWidth: (size * _pixelsPerPoint).round(),
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
