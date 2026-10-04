import 'dart:convert';
import 'dart:typed_data';

import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/services/contact_launcher.dart';
import 'package:norbu_flow/core/services/document_printer.dart';
import 'package:norbu_flow/core/services/file_cache.dart';
import 'package:norbu_flow/core/services/photo_picker.dart';

/// A one-pixel PNG for each side of a card: enough for a screen to show.
final frontPage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
);
final backPage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOoktf+DwADnwHE9CgVtQAAAABJRU5ErkJggg==',
);

/// Stands in for the device's printing: notes what it was asked to print,
/// share and draw, and draws every card as [frontPage] and [backPage].
class RecordingPrinter implements DocumentPrinter {
  final printed = <String, Uint8List>{};

  /// Full pages sent to the printer as they are: letters.
  final printedPages = <String, Uint8List>{};
  final shared = <String, Uint8List>{};
  final drawn = <Uint8List>[];
  AppFailure? pagesFailure;

  @override
  Future<List<Uint8List>> pages(Uint8List pdf) async {
    if (pagesFailure case final failure?) throw failure;
    drawn.add(pdf);
    return [frontPage, backPage];
  }

  @override
  Future<List<Uint8List>> fullPages(Uint8List pdf) async {
    if (pagesFailure case final failure?) throw failure;
    drawn.add(pdf);
    return [frontPage];
  }

  @override
  Future<void> print(Uint8List pdf, {required String name}) async =>
      printed[name] = pdf;

  @override
  Future<void> printPage(Uint8List pdf, {required String name}) async =>
      printedPages[name] = pdf;

  @override
  Future<void> share(Uint8List pdf, {required String fileName}) async =>
      shared[fileName] = pdf;
}

/// Stands in for the device's cache folder: keeps files in memory.
class MemoryFileCache implements FileCache {
  final files = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String name) async => files[name];

  @override
  Future<void> write(String name, Uint8List bytes) async => files[name] = bytes;

  @override
  Future<void> remove(String name) async => files.remove(name);
}

/// Stands in for the mail app and WhatsApp: notes who was to be reached.
class RecordingLauncher implements ContactLauncher {
  final emailed = <String>[];
  final messaged = <String>[];
  AppFailure? failWith;

  @override
  Future<void> email(String address) async {
    if (failWith case final failure?) throw failure;
    emailed.add(address);
  }

  @override
  Future<void> whatsApp(String digits) async {
    if (failWith case final failure?) throw failure;
    messaged.add(digits);
  }
}

/// A camera or gallery that always hands over the same picture.
class OnePhoto implements PhotoPicker {
  OnePhoto(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async => bytes;
}
