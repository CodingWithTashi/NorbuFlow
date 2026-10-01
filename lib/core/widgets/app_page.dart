import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../layout/responsive.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'buttons.dart';
import 'decor.dart';

/// The frame every in-app screen sits in: an optional back link, scrolling
/// content capped to a readable width, and an optional pinned action area.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.backLabel,
    this.onBack,
    this.bottom,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.padding,
    this.scrollable = true,
  });

  final Widget child;

  /// Name of the screen "Back" returns to, e.g. "Home".
  final String? backLabel;
  final VoidCallback? onBack;

  /// Pinned below the content, above the keyboard.
  final Widget? bottom;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  /// Set to false when [child] brings its own scrolling (long lists).
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final hasBack = backLabel != null;
    final contentPadding =
        padding ??
        (hasBack
            ? const EdgeInsets.fromLTRB(20, 0, 20, 16)
            : const EdgeInsets.fromLTRB(20, 20, 20, 24));
    final framed = ContentFrame(maxWidth: maxWidth, child: child);

    return ColoredBox(
      color: context.colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasBack)
            ContentFrame(
              maxWidth: maxWidth,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: BackLink(label: backLabel!, onPressed: onBack),
                ),
              ),
            ),
          Expanded(
            child: scrollable
                ? SingleChildScrollView(padding: contentPadding, child: framed)
                : Padding(padding: contentPadding, child: framed),
          ),
          if (bottom != null)
            BottomActionBar(maxWidth: maxWidth, child: bottom!),
        ],
      ),
    );
  }
}

/// "‹ Members" style link at the top of a detail screen.
class BackLink extends StatelessWidget {
  const BackLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return LinkButton(label: '‹ $label', onPressed: onPressed);
  }
}

/// The pinned strip that holds a screen's primary action.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: ContentFrame(maxWidth: maxWidth, child: child),
      ),
    );
  }
}

/// A multi-step flow: progress header, one step of content, and "Next".
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.flowName,
    required this.step,
    required this.stepCount,
    required this.title,
    required this.onBack,
    required this.nextLabel,
    required this.onNext,
    required this.child,
    this.busy = false,
    this.centerContent = false,
  });

  final String flowName;

  /// One-based index of the current step.
  final int step;
  final int stepCount;
  final String title;
  final VoidCallback onBack;
  final String nextLabel;
  final VoidCallback onNext;
  final Widget child;
  final bool busy;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    final header = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: ContentFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BackLink(label: l10n.commonBack, onPressed: onBack),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: IconLabel(
                        icon: AppIcons.check,
                        label: l10n.wizardProgressSaved,
                        textAlign: TextAlign.end,
                        style: type.sans(
                          14,
                          color: colors.success,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            flowName,
                            style: type.sans(
                              15,
                              color: colors.inkMuted,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.wizardStepOf(step, stepCount),
                          style: type.sans(
                            15,
                            weight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 1; i <= stepCount; i++) ...[
                          if (i > 1) const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: i <= step
                                    ? AppPalette.amber
                                    : colors.line,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(title, style: type.serif(24)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return ColoredBox(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ContentFrame(child: child),
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(
              label: nextLabel,
              onPressed: onNext,
              busy: busy,
            ),
          ),
        ],
      ),
    );
  }
}
