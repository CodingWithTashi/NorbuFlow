import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/services/contact_launcher.dart';
import 'package:norbu_flow/core/services/file_cache.dart';
import 'package:norbu_flow/core/services/photo_picker.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  group('getting in touch', () {
    late _Device device;
    const launcher = DeviceContactLauncher();

    setUp(() => UrlLauncherPlatform.instance = device = _Device());

    test('WhatsApp opens the app itself on that person\'s chat', () async {
      await launcher.whatsApp('919876543210');

      expect(device.opened, ['whatsapp://send?phone=919876543210']);
      // In the other app, never inside this one.
      expect(device.modes, [PreferredLaunchMode.externalApplication]);
    });

    test('with no WhatsApp on the device, opens its page in the browser, '
        'which offers to install it', () async {
      device.without.add('whatsapp');

      await launcher.whatsApp('919876543210');

      expect(device.opened, [
        'whatsapp://send?phone=919876543210',
        'https://wa.me/919876543210',
      ]);
    });

    test('a device that throws for a link it has no app for is treated the '
        'same', () async {
      device
        ..without.add('whatsapp')
        ..throws = true;

      await launcher.whatsApp('14165550142');

      expect(device.opened.last, 'https://wa.me/14165550142');
    });

    test('email opens the mail app with the address filled in', () async {
      await launcher.email('tenzin.dolma@example.org');

      expect(device.opened, ['mailto:tenzin.dolma@example.org']);
      expect(device.modes, [PreferredLaunchMode.externalApplication]);
    });

    test('says so when nothing on the device can open it', () async {
      device.without.addAll(['mailto', 'whatsapp', 'https']);

      await expectLater(
        launcher.email('tenzin.dolma@example.org'),
        throwsA(isA<UnavailableFailure>()),
      );
      await expectLater(
        launcher.whatsApp('14165550142'),
        throwsA(isA<UnavailableFailure>()),
      );
    });
  });

  group('taking a photo', () {
    test('opens the back camera, which does not mirror, and keeps the photo '
        'a workable size', () async {
      final camera = _Camera();

      await DevicePhotoPicker(camera).pick(PhotoOrigin.camera);

      expect(camera.source, ImageSource.camera);
      expect(camera.device, CameraDevice.rear);
      expect((camera.maxWidth, camera.maxHeight), (1600, 1600));
    });

    test(
      'uploads from the gallery, and takes "nothing chosen" calmly',
      () async {
        final camera = _Camera();

        expect(
          await DevicePhotoPicker(camera).pick(PhotoOrigin.gallery),
          isNull,
        );
        expect(camera.source, ImageSource.gallery);
      },
    );

    test('says so when the device has no camera to give', () async {
      final camera = _Camera()..failure = StateError('no camera');

      await expectLater(
        DevicePhotoPicker(camera).pick(PhotoOrigin.camera),
        throwsA(isA<UnavailableFailure>()),
      );
    });
  });

  group('files kept on the device', () {
    late Directory folder;
    late _Paths paths;
    final bytes = Uint8List.fromList([1, 2, 3]);

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('norbu_cache_test');
      addTearDown(() => folder.delete(recursive: true));
      PathProviderPlatform.instance = paths = _Paths(folder.path);
    });

    test('are written, read back and removed by name', () async {
      final cache = DeviceFileCache();
      expect(await cache.read('cards/card-1.pdf'), isNull);

      await cache.write('cards/card-1.pdf', bytes);
      expect(await cache.read('cards/card-1.pdf'), bytes);
      // Still there for the next launch.
      expect(await DeviceFileCache().read('cards/card-1.pdf'), bytes);

      await cache.remove('cards/card-1.pdf');
      expect(await cache.read('cards/card-1.pdf'), isNull);
      // Removing what is not there is no trouble.
      await cache.remove('cards/card-1.pdf');
    });

    test('a device with no cache folder only means fetching again', () async {
      paths.folder = null;
      final cache = DeviceFileCache();

      await cache.write('cards/card-1.pdf', bytes);
      expect(await cache.read('cards/card-1.pdf'), isNull);
      await cache.remove('cards/card-1.pdf');
    });

    test('a write cut short leaves nothing to be read back', () async {
      final cache = DeviceFileCache();
      // What is left behind when the app is killed halfway through.
      await File(
        '${folder.path}/cards/card-1.pdf.part',
      ).create(recursive: true);

      expect(await cache.read('cards/card-1.pdf'), isNull);
      await cache.write('cards/card-1.pdf', bytes);
      expect(await cache.read('cards/card-1.pdf'), bytes);
      expect(
        File('${folder.path}/cards/card-1.pdf.part').existsSync(),
        isFalse,
      );
    });
  });
}

/// A device that opens links, apart from the kinds it has no app for.
class _Device extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final opened = <String>[];
  final modes = <PreferredLaunchMode>[];

  /// Schemes nothing on this device opens.
  final without = <String>{};

  /// Whether it throws for those, as some platforms do, or answers false.
  bool throws = false;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    modes.add(options.mode);
    if (!without.contains(Uri.parse(url).scheme)) return true;
    if (throws) throw StateError('No app for $url');
    return false;
  }
}

class _Camera extends Fake implements ImagePicker {
  ImageSource? source;
  CameraDevice? device;
  double? maxWidth;
  double? maxHeight;
  Object? failure;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (failure case final failure?) throw failure;
    this.source = source;
    device = preferredCameraDevice;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    return null;
  }
}

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Paths(this.folder);

  String? folder;

  @override
  Future<String?> getApplicationCachePath() async => folder;
}
