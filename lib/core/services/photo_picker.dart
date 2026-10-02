import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../error/app_failure.dart';

enum PhotoOrigin { camera, gallery }

/// Gets an image from the device. Behind an interface so view models can be
/// tested without a platform channel.
abstract interface class PhotoPicker {
  /// Returns the chosen image's bytes, or null if the person cancelled.
  Future<Uint8List?> pick(PhotoOrigin origin);
}

final class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async {
    try {
      final file = await _picker.pickImage(
        source: switch (origin) {
          PhotoOrigin.camera => ImageSource.camera,
          PhotoOrigin.gallery => ImageSource.gallery,
        },
        // The back camera: staff photograph the member, and a phone saves
        // what its front camera sees mirrored.
        preferredCameraDevice: CameraDevice.rear,
        // Plenty for an ID card and keeps memory use modest.
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return await file?.readAsBytes();
    } on Object catch (error) {
      // No camera, permission denied, or an unsupported platform.
      throw UnavailableFailure(cause: error);
    }
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
