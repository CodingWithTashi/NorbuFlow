import 'package:flutter/material.dart';

import '../../../../core/models/photo_source.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';

/// A letter's page as it prints, on paper in every theme. A tap opens it
/// large, to pinch and read.
class LetterPageView extends StatelessWidget {
  const LetterPageView(this.page, {super.key});

  final PhotoSource page;

  /// A4: width over height.
  static const aspectRatio = 595.276 / 841.89;

  /// Wide enough to read on a tablet without filling it.
  static const _maxWidth = 520.0;

  void _enlarge(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _EnlargedPage(page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: Semantics(
            button: true,
            label: l10n.letterPageLabel,
            hint: l10n.letterEnlargeHint,
            child: GestureDetector(
              onTap: () => _enlarge(context),
              child: _Sheet(page),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Text(
            l10n.letterEnlargeHint,
            textAlign: TextAlign.center,
            style: context.type.sans(
              14,
              color: context.colors.inkMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// The page on its paper, with a hairline so white paper shows on white.
class _Sheet extends StatelessWidget {
  const _Sheet(this.page);

  final PhotoSource page;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: LetterPageView.aspectRatio,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: AppPalette.paperLine),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(color: AppPalette.paper, child: PhotoImage(page)),
        ),
      ),
    );
  }
}

/// The page filling the screen, to pinch and drag.
class _EnlargedPage extends StatelessWidget {
  const _EnlargedPage(this.page);

  final PhotoSource page;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: LinkButton(
                  label: context.l10n.commonDone,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _Sheet(page),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
