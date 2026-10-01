import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_failure.dart';
import '../error/failure_mapper.dart';
import '../error/failure_text.dart';
import '../theme/app_theme.dart';
import 'buttons.dart';

/// Renders a provider's loading / error / data states the same way on every
/// screen. Previous data stays visible while a refresh is in flight.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) {
      return FailureView(
        failure: FailureMapper.map(value.error!),
        onRetry: onRetry,
      );
    }
    return const LoadingView();
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// A read that failed: plain words and, when possible, a way to try again.
class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MessageView(
      message: failureText(context.l10n, failure),
      action: onRetry == null
          ? null
          : SecondaryButton(
              label: context.l10n.commonRetry,
              onPressed: onRetry,
              expand: false,
            ),
    );
  }
}

/// Centred explanatory text for empty and error states.
class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.type.sans(
                17,
                color: context.colors.inkMuted,
                height: 1.5,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
