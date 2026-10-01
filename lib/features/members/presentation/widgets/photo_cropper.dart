import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Holds the pan and zoom of a photo being cropped to a circle, and renders
/// the result. Owned by the screen so its "Use this photo" button can ask
/// for the cropped image.
class PhotoCropController extends ChangeNotifier {
  /// Diameter of the circular crop window, in logical pixels.
  static const viewport = 240.0;
  static const minZoom = 1.0;
  static const maxZoom = 3.0;

  ui.Image? _image;
  double _zoom = minZoom;
  Offset _offset = Offset.zero;

  ui.Image? get image => _image;
  double get zoom => _zoom;

  /// Decodes [bytes] and resets the crop to the centre of the photo.
  Future<void> load(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _image?.dispose();
    _image = frame.image;
    _zoom = minZoom;
    _offset = Offset.zero;
    notifyListeners();
  }

  /// Scale that makes the photo's shorter side fill the crop window.
  double get _scale {
    final image = _image!;
    return viewport / math.min(image.width, image.height) * _zoom;
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
    final maxX = (size.width - viewport) / 2;
    final maxY = (size.height - viewport) / 2;
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

  /// Renders the part of the photo inside the crop window as a square PNG,
  /// [size] pixels on a side.
  Future<Uint8List> export({int size = 480}) async {
    final image = _image!;
    final scale = _scale;
    final drawn = drawnSize;
    final pan = offset;
    final source = Rect.fromLTWH(
      ((drawn.width - viewport) / 2 - pan.dx) / scale,
      ((drawn.height - viewport) / 2 - pan.dy) / scale,
      viewport / scale,
      viewport / scale,
    );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(size, size);
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

/// Drag to move, slide to zoom. The circle shows exactly what will appear on
/// the ID card.
class PhotoCropper extends StatelessWidget {
  const PhotoCropper({super.key, required this.controller});

  final PhotoCropController controller;

  /// The square the photo is shown in; the crop circle is inset within it.
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

    // Dim everything outside the crop circle, then outline it.
    final window = Rect.fromCircle(
      center: box.center,
      radius: PhotoCropController.viewport / 2,
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(box),
        Path()..addOval(window),
      ),
      Paint()..color = AppPalette.cropScrim,
    );
    canvas.drawOval(
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
