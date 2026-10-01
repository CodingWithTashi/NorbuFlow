import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/failure_text.dart';
import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import 'app_messenger.dart';

/// Draws the current [AppMessage] over the whole app, including sheets and
/// dialogs. Mounted once, in `MaterialApp.builder`.
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(appMessengerProvider);
    final media = MediaQuery.of(context);
    // On phones the toast floats above the tab bar.
    final bottom =
        (context.isCompact ? 96.0 : 32.0) +
        media.viewPadding.bottom +
        media.viewInsets.bottom;

    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          bottom: bottom,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: message == null
                    ? const SizedBox.shrink()
                    : _Toast(key: ObjectKey(message), message: message),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toast extends ConsumerWidget {
  const _Toast({super.key, required this.message});

  final AppMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final text = message.failure != null
        ? failureText(context.l10n, message.failure!)
        : message.text!;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: AppPalette.espresso,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.gold),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: message.isFailure
                        ? AppPalette.danger
                        : AppPalette.success,
                  ),
                  child: AppIcon(
                    message.isFailure ? AppIcons.alert : AppIcons.check,
                    size: 15,
                    color: AppPalette.cream,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: type.sans(16, color: AppPalette.cream, height: 1.4),
                  ),
                ),
                if (message.onUndo != null) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      message.onUndo!();
                      ref.read(appMessengerProvider.notifier).dismiss();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      backgroundColor: AppPalette.amber,
                      foregroundColor: AppPalette.espresso,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: type.sans(
                        16,
                        weight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    child: Text(context.l10n.commonUndo),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
