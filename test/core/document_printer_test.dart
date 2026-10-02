import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/services/document_printer.dart';
import 'package:pdf/pdf.dart';

void main() {
  // An ID card, 159.72 by 252 points, drawn small to keep the test light.
  const dotsPerInch = 60.0;
  final card = RasterPage(133, 210, Uint8List(133 * 210 * 4));

  test('a page\'s size is its pixels at the resolution it was drawn at', () {
    for (final (page, dpi) in [
      (card, dotsPerInch),
      (_blank(1331, 2100), 600.0),
    ]) {
      final size = page.sizeAt(dpi);
      expect(size.x, closeTo(159.6, 0.2));
      expect(size.y, closeTo(252, 0.01));
    }
  });

  test(
    'each page goes on the chosen paper at its true size, centred',
    () async {
      final printed = latin1.decode(
        await atActualSize([card, card], PdfPageFormat.a4, dotsPerInch),
      );

      // Two pages, each the size of the paper rather than of the card.
      final paper = RegExp(r'/MediaBox\[0 0 595\.27\d* 841\.88\d*\]');
      expect(paper.allMatches(printed), hasLength(2));

      // Drawn 159.6 by 252 points, with equal space left and right, and
      // above and below.
      final [width, height, left, bottom] = _imagePlacement(printed);
      expect(width, closeTo(159.6, 0.01));
      expect(height, closeTo(252, 0.01));
      expect(left, closeTo((595.28 - 159.6) / 2, 0.01));
      expect(bottom, closeTo((841.89 - 252) / 2, 0.01));
    },
  );

  test('paper smaller than the page crops it evenly, without shrinking '
      'it', () async {
    // A card printer's own media: the card without its bleed.
    const cardStock = PdfPageFormat(153, 243);

    final printed = latin1.decode(
      await atActualSize([card], cardStock, dotsPerInch),
    );

    final [width, height, left, bottom] = _imagePlacement(printed);
    expect(width, closeTo(159.6, 0.01));
    expect(height, closeTo(252, 0.01));
    expect(left, closeTo(-3.3, 0.01));
    expect(bottom, closeTo(-4.5, 0.01));
  });
}

/// A page of the given size in pixels, with nothing drawn on it.
RasterPage _blank(int width, int height) =>
    RasterPage(width, height, Uint8List(0));

/// Width, height, left and bottom of the image on the first page, in points,
/// worked out from the page's drawing commands.
List<double> _imagePlacement(String document) {
  final stream = RegExp(r'/Contents (\d+) 0 R').firstMatch(document)!.group(1)!;
  final body = RegExp(
    '\\n$stream 0 obj\\n<<[^>]*>>stream\\n([\\s\\S]*?)\\nendstream',
  ).firstMatch(document)!.group(1)!;
  final commands = utf8.decode(zlib.decode(latin1.encode(body)));

  // Each `a 0 0 d x y cm` moves and scales what follows it.
  var (width, height, left, bottom) = (1.0, 1.0, 0.0, 0.0);
  final moves = RegExp(r'([\d.-]+) 0 0 ([\d.-]+) ([\d.-]+) ([\d.-]+) cm');
  for (final move in moves.allMatches(commands)) {
    final [a, d, x, y] = [
      for (var i = 1; i <= 4; i++) double.parse(move.group(i)!),
    ];
    left += x * width;
    bottom += y * height;
    width *= a;
    height *= d;
  }
  return [width, height, left, bottom];
}
