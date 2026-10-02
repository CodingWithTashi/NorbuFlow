import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/card.dart';

/// The outline a photo is cropped to: what is framed is what ends up on the
/// ID card.
@immutable
class PhotoCropShape {
  /// The round photo of the in-app membership card.
  const PhotoCropShape.circle() : aspectRatio = 1, cornerRadius = 0.5;

  /// The photo box of the printed ID card.
  const PhotoCropShape.idCard()
    : aspectRatio = CardPhoto.aspectRatio,
      cornerRadius = CardPhoto.cornerRadius;

  /// Width over height.
  final double aspectRatio;

  /// As a fraction of the width.
  final double cornerRadius;

  /// The outline inside [bounds], which must have this shape's proportions.
  Path outline(Rect bounds) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        bounds,
        Radius.circular(bounds.width * cornerRadius),
      ),
    );

  /// The largest size of this shape whose longer side is [longSide].
  Size sized(double longSide) => aspectRatio >= 1
      ? Size(longSide, longSide / aspectRatio)
      : Size(longSide * aspectRatio, longSide);
}

/// Holds the pan and zoom of a photo being cropped, and renders the result
/// when the screen's "Use this photo" button asks for it.
class PhotoCropController extends ChangeNotifier {
  PhotoCropController({this.shape = const PhotoCropShape.circle()});

  /// Longer side of the crop window, in logical pixels.
  static const viewport = 240.0;
  static const minZoom = 1.0;
  static const maxZoom = 3.0;

  final PhotoCropShape shape;

  ui.Image? _image;
  Future<void> _loading = Future.value();
  double _zoom = minZoom;
  Offset _offset = Offset.zero;

  ui.Image? get image => _image;
  double get zoom => _zoom;

  /// The crop window, in logical pixels.
  Size get window => shape.sized(viewport);

  /// Decodes [bytes] and resets the crop to the centre of the photo.
  Future<void> load(Uint8List bytes) => _loading = _decode(bytes);

  Future<void> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _image?.dispose();
    _image = frame.image;
    _zoom = minZoom;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// Scale at which the photo just covers the crop window, times the zoom.
  double get _scale {
    final image = _image!;
    final cover = math.max(
      window.width / image.width,
      window.height / image.height,
    );
    return cover * _zoom;
  }

  /// Size of the photo as drawn.
  Size get drawnSize {
    final image = _image!;
    return Size(image.width * _scale, image.height * _scale);
  }

  /// Pan of the photo's centre from the window's centre, kept within bounds
  /// so the window never shows past the edge of the photo.
  Offset get offset => _clamp(_offset);

  Offset _clamp(Offset value) {
    final size = drawnSize;
    final maxX = (size.width - window.width) / 2;
    final maxY = (size.height - window.height) / 2;
    return Offset(
      value.dx.clamp(-maxX, maxX).toDouble(),
      value.dy.clamp(-maxY, maxY).toDouble(),
    );
  }

  void panBy(Offset delta) {
    if (_image == null) return;
    _offset = _clamp(_offset + delta);
    notifyListeners();
  }

  void setZoom(double value) {
    if (_image == null) return;
    _zoom = value.clamp(minZoom, maxZoom).toDouble();
    _offset = _clamp(_offset);
    notifyListeners();
  }

  /// Renders the part of the photo inside the crop window as a PNG whose
  /// longer side is [size] pixels.
  Future<Uint8List> export({int size = 480}) async {
    // The button can be tapped while a large photo is still being decoded.
    await _loading;
    final image = _image!;
    final scale = _scale;
    final drawn = drawnSize;
    final pan = offset;
    final source = Rect.fromLTWH(
      ((drawn.width - window.width) / 2 - pan.dx) / scale,
      ((drawn.height - window.height) / 2 - pan.dy) / scale,
      window.width / scale,
      window.height / scale,
    );
    final output = shape.sized(size.toDouble());
    final width = output.width.round();
    final height = output.height.round();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width, height);
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    rendered.dispose();
    return data!.buffer.asUint8List();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }
}

/// Drag to move, slide to zoom. The outline shows exactly what will appear
/// on the ID card.
class PhotoCropper extends StatelessWidget {
  const PhotoCropper({super.key, required this.controller});

  final PhotoCropController controller;

  /// The square the photo is shown in; the crop window is inset within it.
  static const boxSize = 280.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ready = controller.image != null;
        return Column(
          children: [
            GestureDetector(
              onPanUpdate: (details) => controller.panBy(details.delta),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox.square(
                    dimension: boxSize,
                    child: ready
                        ? CustomPaint(painter: _CropPainter(controller))
                        : const ColoredBox(
                            color: AppPalette.espresso,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('−', style: context.type.sans(22, color: colors.inkMuted)),
                Expanded(
                  child: Slider(
                    min: PhotoCropController.minZoom,
                    max: PhotoCropController.maxZoom,
                    value: controller.zoom,
                    onChanged: ready ? controller.setZoom : null,
                    semanticFormatterCallback: (value) =>
                        '${(value * 100).round()}%',
                    label: context.l10n.addCropZoom,
                  ),
                ),
                Text('+', style: context.type.sans(22, color: colors.inkMuted)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.controller) : super(repaint: controller);

  final PhotoCropController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final image = controller.image;
    if (image == null) return;
    final box = Offset.zero & size;
    canvas.drawRect(box, Paint()..color = AppPalette.espresso);

    final drawn = controller.drawnSize;
    final centre = box.center + controller.offset;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: centre, width: drawn.width, height: drawn.height),
      Paint()..filterQuality = FilterQuality.medium,
    );

    // Dim everything outside the crop window, then outline it.
    final window = controller.shape.outline(
      Rect.fromCenter(
        center: box.center,
        width: controller.window.width,
        height: controller.window.height,
      ),
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(box), window),
      Paint()..color = AppPalette.cropScrim,
    );
    canvas.drawPath(
      window,
      Paint()
        ..color = AppPalette.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.controller != controller;
}
