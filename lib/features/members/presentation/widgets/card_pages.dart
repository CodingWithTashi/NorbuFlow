import 'package:flutter/material.dart';

import '../../../../core/models/photo_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/avatars.dart';

/// A printed ID card as it comes out of the printer: its front and back side
/// by side. The pages are the card's own PDF, not a redrawing of it.
class CardPages extends StatelessWidget {
  const CardPages(this.pages, {super.key});

  /// Front, then back. Empty while the card is still being drawn.
  final List<PhotoSource> pages;

  /// Wide enough to read the card, without filling a tablet.
  static const _maxWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final sides = [l10n.newCardFront, l10n.newCardBack];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          for (final (index, page) in pages.take(sides.length).indexed)
            Expanded(
              child: Column(
                children: [
                  Semantics(
                    image: true,
                    label: sides[index],
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        // Paper stays white in dark mode.
                        color: AppPalette.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.line),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: PhotoImage(page),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExcludeSemantics(
                    child: Text(
                      sides[index],
                      style: type.sans(14, color: colors.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
