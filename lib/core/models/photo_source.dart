import 'package:flutter/foundation.dart';

/// Where an image (member photo, temple logo) comes from.
///
/// The fake backend keeps picked images in memory; the Firebase
/// implementation will upload them and hand back [NetworkPhoto]s. Widgets
/// render either through `PhotoImage`, so nothing else has to change.
@immutable
sealed class PhotoSource {
  const PhotoSource();
}

final class MemoryPhoto extends PhotoSource {
  const MemoryPhoto(this.bytes);

  final Uint8List bytes;
}

final class NetworkPhoto extends PhotoSource {
  const NetworkPhoto(this.url);

  final String url;
}
