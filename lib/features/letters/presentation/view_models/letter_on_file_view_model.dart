import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/document_printer.dart';
import '../../../../core/services/file_cache.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/letter_repositories.dart';
import '../../domain/letter.dart';
import 'letters_view_model.dart';

/// A letter on file, as its screen shows it.
typedef LetterPage = ({LetterOnFile onFile, MemoryPhoto page});

/// A letter with its page as a picture, kept on the device after the first
/// look. One provider on purpose: see CLAUDE.md, layer rules.
final letterOnFileProvider = FutureProvider.autoDispose
    .family<LetterPage, String>((ref, letterId) async {
      final letter = ref.watch(
        letterProvider(letterId).select((letter) => letter.value),
      );
      if (letter == null) throw const NotFoundFailure();
      final printer = ref.watch(documentPrinterProvider);
      final cache = ref.watch(fileCacheProvider);
      final onFile = await ref
          .watch(letterRepositoryProvider)
          .fetch(ref.watch(activeTempleIdProvider), letter);
      return (onFile: onFile, page: await _pageOf(onFile, printer, cache));
    });

/// The picture of a letter's page: the one kept from last time, or drawn
/// now and kept for the next.
Future<MemoryPhoto> _pageOf(
  LetterOnFile onFile,
  DocumentPrinter printer,
  FileCache cache,
) async {
  final name = LetterFiles.page(onFile.letter.id);
  final kept = await cache.read(name);
  if (kept != null) return MemoryPhoto(kept);

  final drawn = await printer.pagePhotos(onFile.pdf);
  await cache.write(name, drawn.first.bytes);
  return drawn.first;
}

/// What a letter's screen can do with it. Failures have already been shown,
/// so callers have nothing to handle.
class LetterActions {
  LetterActions(this._ref);

  final Ref _ref;

  /// Sends the letter to a printer, as a print job called [title].
  Future<void> printLetter(String letterId, String title) => runCommand(
    _ref,
    () async => _ref
        .read(documentPrinterProvider)
        .printPage(await _pdfOf(letterId), name: title),
    source: 'letters.print',
  );

  /// Opens the share sheet with the letter, as a file named after [title].
  Future<void> shareLetter(String letterId, String title) => runCommand(
    _ref,
    () async => _ref
        .read(documentPrinterProvider)
        .share(await _pdfOf(letterId), fileName: '$title.pdf'),
    source: 'letters.share',
  );

  Future<Uint8List> _pdfOf(String letterId) async =>
      (await _ref.read(letterOnFileProvider(letterId).future)).onFile.pdf;
}

final letterActionsProvider = Provider<LetterActions>(LetterActions.new);
