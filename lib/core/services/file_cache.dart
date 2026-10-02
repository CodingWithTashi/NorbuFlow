import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Files the app keeps on the device to save fetching them again. The
/// device may clear them at any time, so nothing here is the only copy.
abstract interface class FileCache {
  /// The file kept as [name], or null if there is none.
  Future<Uint8List?> read(String name);

  Future<void> write(String name, Uint8List bytes);

  Future<void> remove(String name);
}

/// The app's own cache folder. A cache that cannot be read or written is
/// only a slower app, so every failure here is a miss, never an error.
final class DeviceFileCache implements FileCache {
  DeviceFileCache();

  late final Future<Directory> _folder = getApplicationCacheDirectory();

  Future<File> _file(String name) async =>
      File('${(await _folder).path}/$name');

  @override
  Future<Uint8List?> read(String name) async {
    try {
      final file = await _file(name);
      return await file.exists() ? await file.readAsBytes() : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    try {
      final file = await _file(name);
      await file.parent.create(recursive: true);
      // Under another name first: a file cut short is never read back.
      final part = File('${file.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
    } on Object {
      // Not kept: it is fetched again next time.
    }
  }

  @override
  Future<void> remove(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
    } on Object {
      // Left behind: the device clears its cache in its own time.
    }
  }
}

final fileCacheProvider = Provider<FileCache>((ref) => DeviceFileCache());
