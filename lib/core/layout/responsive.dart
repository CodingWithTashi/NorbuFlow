import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Centres [child] and caps its width so lines stay readable on tablets.
class ContentFrame extends StatelessWidget {
  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A grid whose column count follows the available width, and whose rows
/// grow to fit their tallest tile (so large text never overflows).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 160,
    this.minColumns = 2,
    this.maxColumns = 6,
    this.spacing = 14,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int minColumns;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit =
            ((constraints.maxWidth + spacing) / (minItemWidth + spacing))
                .floor();
        final columns = fit.clamp(minColumns, maxColumns);
        final rowCount = (children.length / columns).ceil();
        return Column(
          children: [
            for (var row = 0; row < rowCount; row++) ...[
              if (row > 0) SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var col = 0; col < columns; col++) ...[
                      if (col > 0) SizedBox(width: spacing),
                      Expanded(
                        child: row * columns + col < children.length
                            ? children[row * columns + col]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Two groups of content: side by side when the pane is wide enough,
/// stacked otherwise. Lives inside a scroll view.
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = Breakpoints.twoPane,
    this.gap = 24,
    this.stackedGap = 14,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
  });

  final Widget primary;
  final Widget secondary;
  final double breakpoint;
  final double gap;
  final double stackedGap;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              SizedBox(height: stackedGap),
              secondary,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: primaryFlex, child: primary),
            SizedBox(width: gap),
            Expanded(flex: secondaryFlex, child: secondary),
          ],
        );
      },
    );
  }
}

/// Lays children out in equal-width columns with a fixed gap.
class EqualRow extends StatelessWidget {
  const EqualRow({super.key, required this.children, this.gap = 10});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) SizedBox(width: gap),
            Expanded(child: child),
          ],
        ],
      ),
    );
  }
}

/// Clamps a text scale so layouts stay usable at extreme accessibility sizes.
double clampTextScale(double scale) => math.min(math.max(scale, 0.9), 1.8);
