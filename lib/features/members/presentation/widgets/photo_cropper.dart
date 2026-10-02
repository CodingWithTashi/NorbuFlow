import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/buttons.dart';
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

/// Holds how a photo being cropped is moved, zoomed, turned and flipped,
/// and renders the result when the screen's "Use this photo" button asks.
class PhotoCropController extends ChangeNotifier {
  PhotoCropController({this.shape = const PhotoCropShape.circle()});

  /// Longer side of the crop window, in logical pixels.
  static const viewport = 240.0;
  static const minZoom = 1.0;
  static const maxZoom = 3.0;

  /// How far the photo can be straightened either way. Quarter turns do the
  /// rest, so between them every angle can be reached.
  static const maxTilt = math.pi / 4;

  static const _quarter = math.pi / 2;

  /// A tilt this close to level is taken to mean level.
  static const _snap = math.pi / 180;

  /// Two fingers must twist this far before the photo turns, so that a
  /// pinch does not tilt it.
  static const _twistSlop = 8 * math.pi / 180;

  /// And spread or close by this much before it zooms, so a twist does not.
  static const _pinchSlop = 0.04;

  /// How far the photo must reach past the window, so that its soft edge
  /// never shows as a pale line along the side of the cropped photo.
  static const _bleed = 1.0;

  final PhotoCropShape shape;

  ui.Image? _image;
  Future<void> _loading = Future.value();

  // Screen pixels per photo pixel, as asked for. The photo is never drawn
  // smaller than covers the window: zero asks for exactly that.
  double _wanted = 0;
  Offset _offset = Offset.zero;
  int _quarters = 0;
  double _tilt = 0;
  bool _flipped = false;

  // Where a drag, pinch or twist started from, once one has.
  bool _tracking = false;
  Offset _gestureFocal = Offset.zero;
  Offset _gestureOffset = Offset.zero;
  double _gestureScale = 1;
  double _gestureWanted = 0;
  int _gestureQuarters = 0;
  double _gestureTilt = 0;

  ui.Image? get image => _image;

  /// How much larger the photo is drawn than just covers the window.
  double get zoom {
    if (_image == null) return minZoom;
    // Dividing can land a hair outside the range a slider accepts.
    return (_scale / _cover).clamp(minZoom, maxZoom).toDouble();
  }

  /// The turn of the photo, clockwise, in radians: quarters plus [tilt].
  double get rotation => _within(_turn);

  /// The part of the turn that straightens the photo, within [maxTilt].
  double get tilt => _tilt;

  /// Whether the photo is mirrored left to right.
  bool get flipped => _flipped;

  /// Whether anything has been moved since the photo was loaded.
  bool get edited =>
      zoom != minZoom ||
      _offset != Offset.zero ||
      _quarters != 0 ||
      _tilt != 0 ||
      _flipped;

  /// The crop window, in logical pixels.
  Size get window => shape.sized(viewport);

  /// Decodes [bytes] and resets the crop to the centre of the photo.
  Future<void> load(Uint8List bytes) => _loading = _decode(bytes);

  Future<void> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    _image?.dispose();
    _image = frame.image;
    _restore();
    notifyListeners();
  }

  void _restore() {
    _wanted = 0;
    _offset = Offset.zero;
    _quarters = 0;
    _tilt = 0;
    _flipped = false;
  }

  double get _turn => _quarters * _quarter + _tilt;

  /// How much of the photo, along its own sides, the window spans once the
  /// photo is turned.
  Size get _windowAlongPhoto {
    final cos = math.cos(_turn).abs();
    final sin = math.sin(_turn).abs();
    return Size(
      window.width * cos + window.height * sin + _bleed,
      window.width * sin + window.height * cos + _bleed,
    );
  }

  /// Scale at which the turned photo just covers the crop window.
  double get _cover {
    final image = _image!;
    final span = _windowAlongPhoto;
    return math.max(span.width / image.width, span.height / image.height);
  }

  /// Scale the photo is drawn at: what was asked for, within what covers
  /// the window and [maxZoom] times that.
  double get _scale {
    final cover = _cover;
    return _wanted.clamp(cover, cover * maxZoom).toDouble();
  }

  /// Size of the photo as drawn.
  Size get drawnSize {
    final image = _image!;
    final scale = _scale;
    return Size(image.width * scale, image.height * scale);
  }

  /// Pan of the photo's centre from the window's centre, kept within bounds
  /// so the window never shows past the edge of the photo.
  Offset get offset => _image == null ? Offset.zero : _clamp(_offset);

  Offset _clamp(Offset value) {
    // Measured along the photo's own sides, which is where its edges are.
    final along = _turned(value, -_turn);
    final size = drawnSize;
    final span = _windowAlongPhoto;
    final maxX = math.max(0.0, (size.width - span.width) / 2);
    final maxY = math.max(0.0, (size.height - span.height) / 2);
    return _turned(
      Offset(
        along.dx.clamp(-maxX, maxX).toDouble(),
        along.dy.clamp(-maxY, maxY).toDouble(),
      ),
      _turn,
    );
  }

  static Offset _turned(Offset value, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return Offset(
      value.dx * cos - value.dy * sin,
      value.dx * sin + value.dy * cos,
    );
  }

  /// [angle] brought into the range of one turn, half each way.
  static double _within(double angle) {
    final turned = angle.remainder(2 * math.pi);
    if (turned > math.pi) return turned - 2 * math.pi;
    if (turned < -math.pi) return turned + 2 * math.pi;
    return turned;
  }

  static double _levelled(double tilt) => tilt.abs() < _snap ? 0 : tilt;

  /// [value] less the first [slop] of it, which is taken for a wobble.
  static double _past(double value, double slop) =>
      value.abs() <= slop ? 0 : value - slop * value.sign;

  /// Moves the photo so the spot that was under [anchor] before a zoom or
  /// turn is under [movedTo] now. Both are measured from the window's centre.
  void _keep(
    Offset anchor, {
    required Offset offset,
    required double scale,
    required double turn,
    Offset? movedTo,
  }) {
    final arm = _turned(anchor - offset, _turn - turn) * (_scale / scale);
    _offset = _clamp((movedTo ?? anchor) - arm);
  }

  /// Runs [change] with the middle of the window staying where it is.
  void _aboutCentre(VoidCallback change) {
    if (_image == null) return;
    final offset = _offset;
    final scale = _scale;
    final turn = _turn;
    change();
    _keep(Offset.zero, offset: offset, scale: scale, turn: turn);
    notifyListeners();
  }

  void setZoom(double value) => _aboutCentre(() {
    final zoom = value.clamp(minZoom, maxZoom).toDouble();
    _wanted = zoom == minZoom ? 0 : _cover * zoom;
  });

  /// Straightens the photo by [angle], on top of its quarter turns.
  void setTilt(double angle) => _aboutCentre(() {
    _tilt = _levelled(angle.clamp(-maxTilt, maxTilt).toDouble());
  });

  /// Turns the photo a quarter turn: clockwise for 1, the other way for -1.
  void turnBy(int quarters) => _aboutCentre(() {
    _quarters = (_quarters + quarters) % 4;
  });

  /// Mirrors what is framed, left to right: for a selfie a phone saved
  /// mirrored. A photo that was straightened stays straight.
  void flip() {
    if (_image == null) return;
    _flipped = !_flipped;
    _quarters = -_quarters % 4;
    _tilt = -_tilt;
    _offset = _clamp(Offset(-_offset.dx, _offset.dy));
    notifyListeners();
  }

  /// Puts the photo back as it was loaded.
  void reset() {
    if (_image == null) return;
    _restore();
    notifyListeners();
  }

  /// Fingers are down at [focal], measured from the middle of the window.
  void startGesture(Offset focal) {
    _tracking = _image != null;
    if (!_tracking) return;
    _gestureFocal = focal;
    _gestureOffset = _offset;
    _gestureScale = _scale;
    _gestureWanted = _wanted;
    _gestureQuarters = _quarters;
    _gestureTilt = _tilt;
  }

  /// The fingers are now at [focal]; two also zoom by [scale] and turn by
  /// [twist], from where they started. The spot under them stays under them.
  void updateGesture({
    required Offset focal,
    double scale = 1,
    double twist = 0,
  }) {
    if (_image == null) return;
    // Fingers that were down before the photo was ready start from here.
    if (!_tracking) {
      startGesture(focal);
      return;
    }
    // Flutter may report a small twist as nearly a whole turn.
    _twistBy(_past(_within(twist), _twistSlop));
    _pinchBy(1 + _past(scale - 1, _pinchSlop));
    _keep(
      _gestureFocal,
      offset: _gestureOffset,
      scale: _gestureScale,
      turn: _gestureQuarters * _quarter + _gestureTilt,
      movedTo: focal,
    );
    notifyListeners();
  }

  /// Turns by [angle] from where the gesture began. A tilt carried past
  /// either end of its range goes on into the next quarter turn.
  void _twistBy(double angle) {
    var quarters = _gestureQuarters;
    var tilt = _gestureTilt + angle;
    while (tilt > maxTilt) {
      tilt -= _quarter;
      quarters++;
    }
    while (tilt < -maxTilt) {
      tilt += _quarter;
      quarters--;
    }
    _quarters = quarters % 4;
    _tilt = _levelled(tilt);
  }

  /// Zooms by [factor] from where the gesture began. Pinched down to what
  /// just covers the window, the photo goes back to following that size.
  void _pinchBy(double factor) {
    if (factor == 1) {
      _wanted = _gestureWanted;
      return;
    }
    final cover = _cover;
    final asked = _gestureScale * factor;
    _wanted = asked <= cover ? 0 : math.min(asked, cover * maxZoom);
  }

  /// Draws the photo as framed, with the crop window centred on [centre]. The
  /// screen and the export both use it, so what is framed is what is kept.
  void paintPhoto(Canvas canvas, Offset centre, FilterQuality quality) {
    final image = _image;
    if (image == null) return;
    final pan = offset;
    final drawn = drawnSize;
    canvas
      ..save()
      ..translate(centre.dx + pan.dx, centre.dy + pan.dy)
      ..rotate(_turn);
    if (_flipped) canvas.scale(-1, 1);
    canvas
      ..drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(
          center: Offset.zero,
          width: drawn.width,
          height: drawn.height,
        ),
        Paint()..filterQuality = quality,
      )
      ..restore();
  }

  /// Renders the part of the photo inside the crop window as a PNG whose
  /// longer side is [size] pixels.
  Future<Uint8List> export({int size = 480}) async {
    // The button can be tapped while a large photo is still being decoded.
    await _loading;
    final output = shape.sized(size.toDouble());
    final width = output.width.round();
    final height = output.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..clipRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()))
      ..scale(width / window.width, height / window.height);
    paintPhoto(canvas, window.center(Offset.zero), FilterQuality.high);
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

/// A pinch, twist or drag that is taken as soon as a finger lands, so the
/// page behind does not scroll instead and the photo does not jump.
class _PhotoGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// The photo editor: drag, pinch and twist on the photo, sliders and buttons
/// below. The outline shows exactly what will appear on the ID card.
class PhotoCropper extends StatelessWidget {
  const PhotoCropper({super.key, required this.controller});

  final PhotoCropController controller;

  /// The square the photo is shown in; the crop window is inset within it.
  static const boxSize = 280.0;

  static const _zoomStep = 0.25;
  static const _degree = math.pi / 180;

  /// The middle of the box, which is the middle of the crop window.
  static const _centre = Offset(boxSize / 2, boxSize / 2);

  void _fingersDown(ScaleStartDetails details) =>
      controller.startGesture(details.localFocalPoint - _centre);

  void _fingersMoved(ScaleUpdateDetails details) {
    // One finger only moves the photo.
    final two = details.pointerCount > 1;
    controller.updateGesture(
      focal: details.localFocalPoint - _centre,
      scale: two ? details.scale : 1,
      twist: two ? details.rotation : 0,
    );
  }

  /// Straightens with the slider, with a tick felt as the photo comes level.
  void _straighten(double angle) {
    final level = controller.tilt == 0;
    controller.setTilt(angle);
    if (!level && controller.tilt == 0) HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ready = controller.image != null;
        VoidCallback? whenReady(VoidCallback action) => ready ? action : null;

        return Column(
          children: [
            RawGestureDetector(
              gestures: {
                _PhotoGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      _PhotoGestureRecognizer
                    >(_PhotoGestureRecognizer.new, (recognizer) {
                      recognizer
                        ..onStart = _fingersDown
                        ..onUpdate = _fingersMoved;
                    }),
              },
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
            const SizedBox(height: 12),
            _SliderRow(
              lower: _RoundIconButton(
                icon: AppIcons.minus,
                label: l10n.addCropZoomOut,
                onPressed: whenReady(
                  () => controller.setZoom(controller.zoom - _zoomStep),
                ),
              ),
              upper: _RoundIconButton(
                icon: AppIcons.plus,
                label: l10n.addCropZoomIn,
                onPressed: whenReady(
                  () => controller.setZoom(controller.zoom + _zoomStep),
                ),
              ),
              slider: Semantics(
                label: l10n.addCropZoom,
                child: Slider(
                  min: PhotoCropController.minZoom,
                  max: PhotoCropController.maxZoom,
                  value: controller.zoom,
                  onChanged: ready ? controller.setZoom : null,
                  semanticFormatterCallback: (value) =>
                      l10n.addCropZoomValue((value * 100).round()),
                ),
              ),
            ),
            _SliderRow(
              lower: _RoundIconButton(
                icon: AppIcons.turnLeft,
                label: l10n.addCropTurnLeft,
                onPressed: whenReady(() => controller.turnBy(-1)),
              ),
              upper: _RoundIconButton(
                icon: AppIcons.turnRight,
                label: l10n.addCropTurnRight,
                onPressed: whenReady(() => controller.turnBy(1)),
              ),
              // Level is the middle, so the track is not filled from an end.
              slider: SliderTheme(
                data: SliderTheme.of(
                  context,
                ).copyWith(activeTrackColor: context.colors.line),
                child: Semantics(
                  label: l10n.addCropRotate,
                  child: Slider(
                    min: -PhotoCropController.maxTilt,
                    max: PhotoCropController.maxTilt,
                    value: controller.tilt,
                    onChanged: ready ? _straighten : null,
                    semanticFormatterCallback: (value) =>
                        l10n.addCropTiltValue((value / _degree).round()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            EqualRow(
              children: [
                SecondaryButton(
                  label: l10n.addCropFlip,
                  icon: AppIcons.flip,
                  minHeight: 48,
                  fontSize: 16,
                  onPressed: whenReady(controller.flip),
                ),
                SecondaryButton(
                  label: l10n.addCropReset,
                  minHeight: 48,
                  fontSize: 16,
                  onPressed: controller.edited ? controller.reset : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A slider between the two buttons that step it down and up.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.lower,
    required this.slider,
    required this.upper,
  });

  final Widget lower;
  final Widget slider;
  final Widget upper;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        lower,
        Expanded(child: slider),
        upper,
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      enabled: onPressed != null,
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: AppIcon(
              icon,
              size: 24,
              color: onPressed == null ? colors.line : colors.inkMuted,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.controller) : super(repaint: controller);

  final PhotoCropController controller;

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.image == null) return;
    final box = Offset.zero & size;
    canvas
      ..clipRect(box)
      ..drawRect(box, Paint()..color = AppPalette.espresso);
    controller.paintPhoto(canvas, box.center, FilterQuality.medium);

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
