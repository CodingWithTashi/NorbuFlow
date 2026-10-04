import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/error/validation_issue.dart';
import '../../../core/models/formatted_text.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../domain/letter.dart';

typedef _Filed = ({Letter letter, List<TextLine> body});

/// Issues letters without a backend. Each temple starts with a few, and the
/// "letter" is a plain page, not a temple's letterhead.
final class FakeLetterRepository extends FakeRepository
    implements LetterRepository {
  FakeLetterRepository(super.latency, this._clock);

  /// The room a letterhead has for the body, and about what fits on a line.
  static const maxLines = 25;
  static const _lineLength = 92;

  static const _firstNumber = 1001;

  // Latin, and the punctuation a word processor puts in.
  static final _unprintable = RegExp('[^ -ÿ‘’“”–—…•]');

  final Clock _clock;

  /// Each temple's letters, the newest first.
  final _letters = <String, List<_Filed>>{};

  /// What each request made, so that one sent twice issues one letter.
  final _issued = <String, IssuedLetter>{};

  @override
  Future<List<Letter>> fetchLetters(String templeId) =>
      respond(() => [for (final filed in _of(templeId)) filed.letter]);

  @override
  Future<LetterPreviewOutcome> preview(
    String templeId,
    LetterRequest request,
  ) async {
    final lines = await respond(() => _linesOf(request));
    if (lines > maxLines) return LetterTooLong(lines - maxLines);
    final number = request.number ?? _next(templeId);
    return LetterPreviewed(
      LetterPreview(
        number: number,
        pdf: await _page(request, number),
        spare: maxLines - lines,
      ),
    );
  }

  @override
  Future<LetterOutcome> issue(String templeId, LetterRequest request) async {
    if (_issued[request.id] case final issued?) return LetterIssued(issued);

    final lines = await respond(() => _linesOf(request));
    if (lines > maxLines) {
      throw const ValidationFailure({
        'body': ValidationIssue.letterBodyTooLong,
      });
    }
    final letters = _of(templeId);
    final typed = request.number;
    final holder = letters
        .where((filed) => filed.letter.number == typed)
        .firstOrNull;
    if (holder != null) {
      return LetterNumberTaken(
        name: holder.letter.name,
        number: holder.letter.number,
      );
    }

    final letter = Letter(
      id: request.id,
      number: typed ?? _next(templeId),
      name: request.name,
      memberId: request.memberId,
      validUntil: request.validUntil.dateOnly,
      issuedOn: _clock().dateOnly,
    );
    letters.insert(0, (letter: letter, body: request.body));
    final issued = IssuedLetter(
      letter: letter,
      pdf: await _page(request, letter.number),
    );
    return LetterIssued(_issued[request.id] = issued);
  }

  @override
  Future<LetterOnFile> fetch(String templeId, Letter asked) async {
    final filed = await respond(
      () => _of(templeId).firstWhere(
        (filed) => filed.letter.id == asked.id,
        orElse: () => throw const NotFoundFailure(),
      ),
    );
    final (:letter, :body) = filed;
    return LetterOnFile(
      letter: letter,
      body: body,
      pdf: await _page(
        LetterRequest(
          id: letter.id,
          name: letter.name,
          validUntil: letter.validUntil,
          body: body,
        ),
        letter.number,
      ),
    );
  }

  List<_Filed> _of(String templeId) =>
      _letters.putIfAbsent(templeId, () => _seed(_clock().dateOnly));

  /// The first number at or after the temple's count that no letter carries.
  String _next(String templeId) {
    final taken = {for (final filed in _of(templeId)) filed.letter.number};
    var number = _firstNumber;
    while (taken.contains('$number')) {
      number++;
    }
    return '$number';
  }

  /// How many lines of the page [request] takes. Refuses what cannot print.
  int _linesOf(LetterRequest request) {
    if (request.validUntil.dateOnly.isBefore(_clock().dateOnly)) {
      throw const ValidationFailure({
        'validUntil': ValidationIssue.letterDatePast,
      });
    }
    var lines = 0;
    for (final line in request.body) {
      if (_unprintable.hasMatch(line.text)) {
        throw const ValidationFailure({
          'body': ValidationIssue.letterBodyUnsupported,
        });
      }
      lines += line.isEmpty ? 1 : (line.text.length / _lineLength).ceil();
    }
    return lines;
  }

  static List<_Filed> _seed(DateTime today) {
    _Filed letter(int index, String name, int daysAgo) {
      final issuedOn = today.addDays(-daysAgo);
      return (
        letter: Letter(
          // Its dates move with the clock and a letter's files are kept by
          // its id, so the id carries the day.
          id: 'letter-${issuedOn.isoDate}',
          number: '${_firstNumber + index}',
          name: name,
          validUntil: issuedOn.plusOneYear,
          issuedOn: issuedOn,
        ),
        body: [
          TextLine([
            const TextRun('This letter is to confirm that '),
            TextRun(name, marks: const {TextMark.bold}),
            const TextRun(' has been a dedicated volunteer of our temple.'),
          ]),
          const TextLine([]),
          const TextLine([
            TextRun(
              'If you have any questions, please feel free to contact me.',
            ),
          ]),
        ],
      );
    }

    return [
      letter(2, 'Tenzin Dolma', 5),
      letter(1, 'Karma Dhondup', 40),
      letter(0, 'Pema Lhamo', 400),
    ];
  }

  /// A plain A4 page that says what the letter would.
  static Future<Uint8List> _page(LetterRequest request, String number) {
    pdf.TextStyle styleOf(TextRun run) => pdf.TextStyle(
      fontSize: 11.6,
      lineSpacing: 5.4,
      fontWeight: run.marks.contains(TextMark.bold)
          ? pdf.FontWeight.bold
          : pdf.FontWeight.normal,
      fontStyle: run.marks.contains(TextMark.italic)
          ? pdf.FontStyle.italic
          : pdf.FontStyle.normal,
      decoration: run.marks.contains(TextMark.underline)
          ? pdf.TextDecoration.underline
          : pdf.TextDecoration.none,
    );
    final document = pdf.Document()
      ..addPage(
        pdf.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 50,
            marginRight: 50,
            marginTop: 60,
            marginBottom: 60,
          ),
          build: (context) => pdf.Column(
            crossAxisAlignment: pdf.CrossAxisAlignment.stretch,
            children: [
              pdf.Text(
                'DEMO LETTER',
                textAlign: pdf.TextAlign.center,
                style: const pdf.TextStyle(fontSize: 9),
              ),
              pdf.SizedBox(height: 40),
              pdf.Row(
                mainAxisAlignment: pdf.MainAxisAlignment.spaceBetween,
                children: [
                  pdf.Text('Valid Until ${Formats.date(request.validUntil)}'),
                  pdf.Text('No. $number'),
                ],
              ),
              pdf.SizedBox(height: 16),
              pdf.Text(
                'To Whom It May Concern',
                textAlign: pdf.TextAlign.center,
                style: const pdf.TextStyle(fontSize: 18),
              ),
              pdf.SizedBox(height: 18),
              for (final line in request.body)
                line.isEmpty
                    ? pdf.SizedBox(height: 17)
                    : pdf.RichText(
                        text: pdf.TextSpan(
                          children: [
                            if (line.bullet)
                              const pdf.TextSpan(
                                text: '-  ',
                                style: pdf.TextStyle(fontSize: 11.6),
                              ),
                            for (final run in line.runs)
                              pdf.TextSpan(text: run.text, style: styleOf(run)),
                          ],
                        ),
                      ),
            ],
          ),
        ),
      );
    return guardFailures(document.save);
  }
}
