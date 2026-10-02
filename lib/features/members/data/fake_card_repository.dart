import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;

import '../../../core/data/fake_repository.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/utils/clock.dart';
import '../domain/card.dart';

/// Issues cards without a backend: numbers count up from a made-up start and
/// the "card" is a plain placeholder, not the temple's artwork.
final class FakeCardRepository extends FakeRepository
    implements CardRepository {
  FakeCardRepository(super.latency, this._clock);

  final Clock _clock;
  final _issued = <String, IssuedCard>{};
  int _nextNumber = 194915308;

  @override
  Future<IssuedCard> issue(NewCard card) async =>
      _issued[card.id] ??= await _issue(card);

  Future<IssuedCard> _issue(NewCard card) async {
    final number = await respond(() => '${_nextNumber++}');
    final today = _clock().dateOnly;
    final yearEnd = DateTime(today.year, 7, 31);
    return IssuedCard(
      number: number,
      name: card.name,
      expiresOn: yearEnd.isAfter(today) ? yearEnd : yearEnd.plusOneYear,
      pdf: await guardFailures(() => _placeholder(card.name, number)),
    );
  }

  /// A front and a back the size of a real card.
  static Future<Uint8List> _placeholder(String name, String number) {
    const small = pdf.TextStyle(fontSize: 7);
    pdf.Page side(List<pdf.Widget> lines) => pdf.Page(
      pageFormat: const PdfPageFormat(159.75, 252, marginAll: 12),
      build: (context) => pdf.Center(
        child: pdf.Column(mainAxisSize: pdf.MainAxisSize.min, children: lines),
      ),
    );
    final document = pdf.Document()
      ..addPage(
        side([
          pdf.Text('DEMO CARD', style: small),
          pdf.SizedBox(height: 10),
          pdf.Text(name, style: const pdf.TextStyle(fontSize: 9)),
          pdf.Text(number, style: const pdf.TextStyle(fontSize: 10)),
        ]),
      )
      ..addPage(side([pdf.Text('DEMO CARD, BACK', style: small)]));
    return document.save();
  }
}
