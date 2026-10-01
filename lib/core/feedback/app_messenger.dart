import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_failure.dart';

/// One transient message shown at the bottom of the screen.
///
/// A message carries either ready-made [text] (confirmations written by a
/// view) or a [failure] (localised by the toast host), never both.
@immutable
class AppMessage {
  const AppMessage._({this.text, this.failure, this.onUndo});

  final String? text;
  final AppFailure? failure;
  final VoidCallback? onUndo;

  bool get isFailure => failure != null;
}

/// The app's only channel for toasts: confirmations, undo prompts and
/// failures all pass through here and are rendered by `ToastHost`.
class AppMessenger extends Notifier<AppMessage?> {
  static const _shortDuration = Duration(seconds: 3);
  static const _undoDuration = Duration(seconds: 5);

  Timer? _timer;

  @override
  AppMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String text, {VoidCallback? onUndo}) {
    _emit(
      AppMessage._(text: text, onUndo: onUndo),
      onUndo == null ? _shortDuration : _undoDuration,
    );
  }

  void showFailure(AppFailure failure) {
    _emit(AppMessage._(failure: failure), _shortDuration);
  }

  void dismiss() {
    _timer?.cancel();
    state = null;
  }

  void _emit(AppMessage message, Duration duration) {
    _timer?.cancel();
    state = message;
    _timer = Timer(duration, () => state = null);
  }
}

final appMessengerProvider = NotifierProvider<AppMessenger, AppMessage?>(
  AppMessenger.new,
);

/// Lets widgets write `ref.toast('Saved.')`.
extension ToastRef on WidgetRef {
  void toast(String text, {VoidCallback? onUndo}) =>
      read(appMessengerProvider.notifier).show(text, onUndo: onUndo);
}
