import 'package:flutter/widgets.dart';

/// Material window size classes: phones, small tablets / iPad portrait, and
/// large tablets / iPad landscape.
enum WindowClass {
  compact,
  medium,
  expanded;

  static WindowClass fromWidth(double width) {
    if (width < Breakpoints.medium) return WindowClass.compact;
    if (width < Breakpoints.expanded) return WindowClass.medium;
    return WindowClass.expanded;
  }
}

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  /// Minimum pane width at which a screen splits into two columns. Measured
  /// on the content pane (after the navigation rail), not the window.
  static const double twoPane = 720;

  /// Reading width for forms and single-column pages.
  static const double contentMaxWidth = 720;

  /// Width for pages that show grids or two panes.
  static const double wideContentMaxWidth = 1120;
}

extension WindowClassContext on BuildContext {
  WindowClass get windowClass =>
      WindowClass.fromWidth(MediaQuery.sizeOf(this).width);

  bool get isCompact => windowClass == WindowClass.compact;
}
