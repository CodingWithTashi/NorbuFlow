import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads what was last copied on the device, so that wording written
/// elsewhere can be pasted with one tap.
abstract interface class ClipboardReader {
  /// The copied text, or null if there is none to give.
  Future<String?> text();
}

final class DeviceClipboardReader implements ClipboardReader {
  const DeviceClipboardReader();

  @override
  Future<String?> text() async {
    try {
      final copied = await Clipboard.getData(Clipboard.kTextPlain);
      final text = copied?.text;
      return text == null || text.isEmpty ? null : text;
    } on Object {
      // A device that will not say what was copied has nothing to paste.
      return null;
    }
  }
}

final clipboardReaderProvider = Provider<ClipboardReader>(
  (ref) => const DeviceClipboardReader(),
);
