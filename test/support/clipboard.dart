import 'package:norbu_flow/core/services/clipboard_reader.dart';

/// Stands in for the device's clipboard: holds [copied], or nothing.
class FixedClipboard implements ClipboardReader {
  FixedClipboard([this.copied]);

  String? copied;

  @override
  Future<String?> text() async => copied;
}
