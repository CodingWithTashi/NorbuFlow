import 'package:flutter/material.dart';

import '../../../../core/models/photo_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/avatars.dart';

/// A printed ID card: its front and back side by side, or its front alone.
/// The pages are the card's own PDF, not a redrawing of it.
class CardPages extends StatelessWidget {
  const CardPages(this.pages, {super.key, this.frontOnly = false});

  /// Front, then back. Empty while the card is still being drawn.
  final List<PhotoSource> pages;
  final bool frontOnly;

  /// Wide enough to read the card, without filling a tablet.
  static const _maxWidth = 440.0;

  /// One side takes the room it has when both are shown.
  static const _gap = 16.0;
  static const _oneSideWidth = (_maxWidth - _gap) / 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final sides = [l10n.newCardFront, if (!frontOnly) l10n.newCardBack];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: frontOnly ? _oneSideWidth : _maxWidth,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _gap,
        children: [
          for (final (index, page) in pages.take(sides.length).indexed)
            Expanded(
              child: Column(
                children: [
                  Semantics(
                    image: true,
                    label: sides[index],
                    child: DecoratedBox(
                      // Over the page, not under it: a card whose edge is the
                      // colour of the screen still shows where it ends.
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.line, width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        // Paper stays white in dark mode.
                        child: ColoredBox(
                          color: AppPalette.paper,
                          child: PhotoImage(page),
                        ),
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
