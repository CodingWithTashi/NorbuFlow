import 'dart:convert';
import 'dart:typed_data';

import '../../../core/data/backend.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/models/formatted_text.dart';
import '../../../core/services/file_cache.dart';
import '../../../core/utils/date_only.dart';
import '../../../core/utils/json.dart';
import '../domain/letter.dart';
import 'letter_json.dart';

/// Letters through the backend, which numbers them and sets them on the
/// temple's letterhead. A letter is kept on the device, so it is fetched once.
final class FirebaseLetterRepository implements LetterRepository {
  FirebaseLetterRepository(this._backend, this._cache);

  /// Longer than the 60 seconds the functions themselves are given, so the
  /// app never gives up on a letter the backend goes on to issue.
  static const _timeout = Duration(seconds: 75);

  final Backend _backend;
  final FileCache _cache;

  @override
  Future<List<Letter>> fetchLetters(String templeId) => guardFailures(() async {
    final response = await _backend.call(
      'letters-list',
      input: {'templeId': templeId},
    );
    return (response['letters']! as List).map(letterFromJson).toList();
  });

  @override
  Future<LetterPreviewOutcome> preview(
    String templeId,
    LetterRequest request,
  ) => guardFailures(() async {
    final response = await _backend.call(
      'letters-preview',
      input: _input(templeId, request),
      timeout: _timeout,
    );
    if (response['tooLong'] case final tooLong?) {
      return LetterTooLong((jsonObject(tooLong)['lines']! as num).toInt());
    }
    return LetterPreviewed(
      LetterPreview(
        number: response['number']! as String,
        pdf: letterPdfFromJson(response['file']),
        spare: (response['spare'] as num?)?.toInt() ?? 0,
      ),
    );
  });

  @override
  Future<LetterOutcome> issue(String templeId, LetterRequest request) =>
      guardFailures(() async {
        final response = await _backend.call(
          'letters-create',
          input: {'id': request.id, ..._input(templeId, request)},
          timeout: _timeout,
        );
        if (response['taken'] case final taken?) {
          final holder = jsonObject(taken);
          return LetterNumberTaken(
            name: holder['name']! as String,
            number: holder['number']! as String,
          );
        }
        final letter = letterFromJson(response['letter']);
        final pdf = letterPdfFromJson(response['file']);
        await _keep(letter.id, pdf, request.body);
        return LetterIssued(IssuedLetter(letter: letter, pdf: pdf));
      });

  @override
  Future<LetterOnFile> fetch(String templeId, Letter letter) =>
      guardFailures(() async {
        final (pdf, body) = await (
          _cache.read(LetterFiles.pdf(letter.id)),
          _cache.read(LetterFiles.body(letter.id)),
        ).wait;
        if (pdf != null && body != null) {
          return LetterOnFile(
            letter: letter,
            body: bodyFromJson(jsonDecode(utf8.decode(body))),
            pdf: pdf,
          );
        }
        final response = await _backend.call(
          'letters-get',
          input: {'templeId': templeId, 'letterId': letter.id},
          timeout: _timeout,
        );
        final onFile = LetterOnFile(
          letter: letterFromJson(response['letter']),
          body: bodyFromJson(response['body']),
          pdf: letterPdfFromJson(response['file']),
        );
        await _keep(letter.id, onFile.pdf, onFile.body);
        return onFile;
      });

  static Map<String, Object?> _input(String templeId, LetterRequest request) =>
      {
        'templeId': templeId,
        'name': request.name,
        'memberId': ?request.memberId,
        'validUntil': request.validUntil.isoDate,
        'body': bodyToJson(request.body),
        'number': ?request.number,
      };

  /// Keeps a letter's page and wording on the device under its own id.
  Future<void> _keep(String letterId, Uint8List pdf, List<TextLine> body) => [
    _cache.write(LetterFiles.pdf(letterId), pdf),
    _cache.write(
      LetterFiles.body(letterId),
      utf8.encode(jsonEncode(bodyToJson(body))),
    ),
  ].wait;
}
