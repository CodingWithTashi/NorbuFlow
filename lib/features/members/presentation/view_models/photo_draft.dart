import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/photo_picker.dart';

/// The photo being chosen for an ID card: picked, then cropped to the card.
@immutable
class PhotoDraft {
  const PhotoDraft({this.cropped, this.original, this.cropping = false});

  /// The cropped photo that will go on the card.
  final MemoryPhoto? cropped;

  /// The image as picked, kept so the crop can be adjusted.
  final Uint8List? original;

  /// Whether the crop editor is open.
  final bool cropping;
}

/// Picking and cropping a photo, for the view model of any form that takes
/// one. The form keeps the [PhotoDraft] in its own state.
mixin PhotoDraftCommands<State> on Notifier<State> {
  @protected
  PhotoDraft get photo;

  @protected
  set photo(PhotoDraft value);

  /// Opens the camera or gallery; on success the crop editor opens.
  Future<void> pickPhoto(PhotoOrigin origin) async {
    final result = await runCommand(
      ref,
      () => ref.read(photoPickerProvider).pick(origin),
      source: 'members.pickPhoto',
    );
    final bytes = result.valueOrNull;
    if (bytes == null || !ref.mounted) return;
    photo = PhotoDraft(cropped: photo.cropped, original: bytes, cropping: true);
  }

  void reopenCrop() {
    if (photo.original == null) return;
    photo = PhotoDraft(
      cropped: photo.cropped,
      original: photo.original,
      cropping: true,
    );
  }

  void cancelCrop() =>
      photo = PhotoDraft(cropped: photo.cropped, original: photo.original);

  void useCroppedPhoto(Uint8List bytes) =>
      photo = PhotoDraft(cropped: MemoryPhoto(bytes), original: photo.original);
}
