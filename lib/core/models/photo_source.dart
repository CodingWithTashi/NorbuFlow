import 'package:flutter/foundation.dart';

/// Where an image (member photo, temple logo) comes from: memory if it was
/// just picked or drawn, a link if the backend keeps it. `PhotoImage` shows it.
@immutable
sealed class PhotoSource {
  const PhotoSource();
}

final class MemoryPhoto extends PhotoSource {
  const MemoryPhoto(this.bytes);

  final Uint8List bytes;
}

final class NetworkPhoto extends PhotoSource {
  const NetworkPhoto(this.url, {this.cacheKey});

  final String url;

  /// What the picture is kept under on the device. A link that is signed
  /// afresh each time needs one, or the same picture would download again.
  final String? cacheKey;
}
