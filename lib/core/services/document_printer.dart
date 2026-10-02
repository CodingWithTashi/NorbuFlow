import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';

import '../error/app_failure.dart';

/// What the device can do with a finished PDF: print it, pass it to another
/// app, or draw it for the screen.
abstract interface class DocumentPrinter {
  /// Prints [pdf] at the size of its own pages, whatever paper is chosen.
  Future<void> print(Uint8List pdf, {required String name});

  /// Opens the share sheet for [pdf], unchanged: save it, send it on.
  Future<void> share(Uint8List pdf, {required String fileName});

  /// Each page of [pdf] as a PNG, to show the document itself on screen.
  Future<List<Uint8List>> pages(Uint8List pdf);
}

final class DeviceDocumentPrinter implements DocumentPrinter {
  const DeviceDocumentPrinter();

  /// Twice what an ID card printer resolves.
  static const _dotsPerInch = 600.0;

  /// Sharp on a phone screen held close.
  static const _screenDotsPerInch = 300.0;

  @override
  Future<void> print(Uint8List pdf, {required String name}) => _run(() async {
    final pages = [
      await for (final page in Printing.raster(pdf, dpi: _dotsPerInch))
        RasterPage(page.width, page.height, page.pixels),
    ];
    final first = pages.first.sizeAt(_dotsPerInch);
    await Printing.layoutPdf(
      name: name,
      format: PdfPageFormat(first.x, first.y),
      // Printers stretch a page to fill the paper, so each one is laid out
      // again at its true size on the paper that was chosen.
      onLayout: (paper) =>
          Isolate.run(() => atActualSize(pages, paper, _dotsPerInch)),
    );
  });

  @override
  Future<void> share(Uint8List pdf, {required String fileName}) =>
      _run(() => Printing.sharePdf(bytes: pdf, filename: fileName));

  @override
  Future<List<Uint8List>> pages(Uint8List pdf) => _run(
    () async => [
      await for (final page in Printing.raster(pdf, dpi: _screenDotsPerInch))
        await page.toPng(),
    ],
  );

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      // No printing service on this device, or an unsupported platform.
      throw UnavailableFailure(cause: error);
    }
  }
}

/// One page of a document as pixels (RGBA), ready to be placed on paper.
class RasterPage {
  const RasterPage(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final Uint8List pixels;

  /// The page's size in points when drawn at [dotsPerInch].
  PdfPoint sizeAt(double dotsPerInch) => PdfPoint(
    width * PdfPageFormat.inch / dotsPerInch,
    height * PdfPageFormat.inch / dotsPerInch,
  );
}

/// A PDF on [paper] with each of [pages] centred at its true size: never
/// scaled, and cropped evenly if the paper is smaller.
Future<Uint8List> atActualSize(
  List<RasterPage> pages,
  PdfPageFormat paper,
  double dotsPerInch,
) {
  final document = pdf.Document();
  for (final page in pages) {
    final size = page.sizeAt(dotsPerInch);
    document.addPage(
      pdf.Page(
        pageFormat: PdfPageFormat(paper.width, paper.height),
        build: (_) => pdf.Stack(
          overflow: pdf.Overflow.visible,
          children: [
            pdf.Positioned(
              left: (paper.width - size.x) / 2,
              top: (paper.height - size.y) / 2,
              child: pdf.Image(
                pdf.RawImage(
                  bytes: page.pixels,
                  width: page.width,
                  height: page.height,
                ),
                width: size.x,
                height: size.y,
                fit: pdf.BoxFit.fill,
              ),
            ),
          ],
        ),
      ),
    );
  }
  return document.save();
}

final documentPrinterProvider = Provider<DocumentPrinter>(
  (ref) => const DeviceDocumentPrinter(),
);
