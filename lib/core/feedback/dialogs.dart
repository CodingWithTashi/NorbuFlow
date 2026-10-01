import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/buttons.dart';

/// Shows [builder] the way the device expects: a bottom sheet on phones, a
/// centred dialog on tablets where a full-width sheet would look stranded.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  final colors = context.colors;
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.background,
      barrierColor: AppPalette.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      // Capped so a sliver of the screen behind stays visible and people
      // keep their bearings.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      builder: (context) =>
          _SheetBody(title: title, showHandle: true, child: builder(context)),
    );
  }
  return showDialog<T>(
    context: context,
    barrierColor: AppPalette.scrim,
    builder: (context) => Dialog(
      backgroundColor: colors.background,
      insetPadding: const EdgeInsets.all(32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _SheetBody(
          title: title,
          showHandle: false,
          child: builder(context),
        ),
      ),
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.showHandle,
    required this.child,
  });

  final String title;
  final bool showHandle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        showHandle ? 10 : 24,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle) ...[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Semantics(
            header: true,
            child: Text(title, style: context.type.serif(22)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Asks a yes/no question before something consequential. Returns true only
/// when the person explicitly confirms.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final colors = context.colors;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppPalette.scrim,
    builder: (context) => Dialog(
      backgroundColor: colors.background,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: context.type.serif(22)),
              const SizedBox(height: 12),
              Text(
                message,
                style: context.type.sans(
                  17,
                  color: context.colors.inkMuted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 4),
              LinkButton(
                label: cancelLabel,
                expand: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
