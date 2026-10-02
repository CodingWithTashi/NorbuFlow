import 'package:flutter/material.dart';

import '../../../../core/layout/responsive.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/photo_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../view_models/photo_draft.dart';
import 'photo_cropper.dart';

/// Choosing the photo for an ID card: take or upload one, crop it to the
/// card's shape, and see the result.
class PhotoField extends StatefulWidget {
  const PhotoField({
    super.key,
    required this.photo,
    required this.crop,
    required this.onPick,
    required this.onAdjustCrop,
    required this.onCancelCrop,
    required this.help,
    required this.cropHelp,
    this.current,
    this.errorText,
  });

  final PhotoDraft photo;

  /// The photo already on file, shown until a new one is chosen.
  final PhotoSource? current;
  final PhotoCropController crop;
  final ValueChanged<PhotoOrigin> onPick;
  final VoidCallback onAdjustCrop;
  final VoidCallback onCancelCrop;
  final String help;
  final String cropHelp;
  final String? errorText;

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  static const _previewSize = 200.0;

  @override
  void initState() {
    super.initState();
    _loadCrop();
  }

  @override
  void didUpdateWidget(PhotoField old) {
    super.didUpdateWidget(old);
    if (!old.photo.cropping) _loadCrop();
  }

  /// Opening the crop editor (first pick or "Adjust the crop") puts the
  /// picked image into the controller.
  void _loadCrop() {
    final original = widget.photo.original;
    if (widget.photo.cropping && original != null) widget.crop.load(original);
  }

  @override
  Widget build(BuildContext context) {
    final PhotoField(
      :photo,
      :crop,
      :onPick,
      :onAdjustCrop,
      :onCancelCrop,
      :help,
      :cropHelp,
      :current,
      :errorText,
    ) = widget;
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    if (photo.cropping) {
      return Column(
        children: [
          PhotoCropper(controller: crop),
          const SizedBox(height: 8),
          Text(
            cropHelp,
            textAlign: TextAlign.center,
            style: type.sans(16, color: colors.inkMuted, height: 1.5),
          ),
          LinkButton(
            label: l10n.addChooseDifferentPhoto,
            onPressed: onCancelCrop,
          ),
        ],
      );
    }

    Widget pickButton(AppIconData icon, String label, PhotoOrigin origin) {
      return Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.amber, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onPick(origin),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(icon, size: 28, color: colors.accentText),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: type.sans(17, weight: FontWeight.w700, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // The preview takes the shape the photo was cropped to.
    final frame = crop.shape.sized(_previewSize);
    final outline = _OutlineClipper(crop.shape);
    final chosen = photo.cropped;
    // A new photo, once cropped, takes the place of the one on file.
    final shown = chosen ?? current;
    return Column(
      children: [
        if (shown != null) ...[
          CustomPaint(
            // A ring just outside the photo, with a sliver of page between.
            foregroundPainter: _OutlinePainter.ring(crop.shape),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipPath(
                clipper: outline,
                child: SizedBox.fromSize(
                  size: frame,
                  child: ColoredBox(
                    color: colors.card,
                    child: PhotoImage(shown),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (chosen != null) ...[
            IconLabel(
              icon: AppIcons.check,
              label: l10n.addPhotoReady,
              style: type.sans(
                17,
                weight: FontWeight.w600,
                color: colors.success,
              ),
            ),
            LinkButton(
              label: l10n.addAdjustCrop,
              underline: true,
              onPressed: onAdjustCrop,
            ),
          ],
        ] else ...[
          CustomPaint(
            foregroundPainter: _OutlinePainter.placeholder(crop.shape),
            child: ClipPath(
              clipper: outline,
              child: Container(
                width: frame.width,
                height: frame.height,
                alignment: Alignment.center,
                color: colors.card,
                child: AppIcon(
                  AppIcons.person,
                  size: 72,
                  color: colors.inkMuted,
                  strokeWidth: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        EqualRow(
          gap: 12,
          children: [
            pickButton(AppIcons.camera, l10n.addTakePhoto, PhotoOrigin.camera),
            pickButton(
              AppIcons.image,
              l10n.addUploadPhoto,
              PhotoOrigin.gallery,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (errorText case final error?)
          FieldError(error)
        else
          Text(
            help,
            textAlign: TextAlign.center,
            style: type.sans(15, color: colors.inkMuted, height: 1.5),
          ),
      ],
    );
  }
}

class _OutlineClipper extends CustomClipper<Path> {
  const _OutlineClipper(this.shape);

  final PhotoCropShape shape;

  @override
  Path getClip(Size size) => shape.outline(Offset.zero & size);

  @override
  bool shouldReclip(_OutlineClipper oldClipper) => oldClipper.shape != shape;
}

class _OutlinePainter extends CustomPainter {
  /// A dashed outline where the photo will go.
  const _OutlinePainter.placeholder(this.shape) : dashed = true, inset = 1;

  /// A solid ring just outside a chosen photo.
  const _OutlinePainter.ring(this.shape) : dashed = false, inset = -1;

  final PhotoCropShape shape;
  final bool dashed;

  /// How far inside the widget's edge the line is drawn.
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppPalette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final outline = shape.outline((Offset.zero & size).deflate(inset));
    if (!dashed) return canvas.drawPath(outline, paint);
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 14) {
        canvas.drawPath(metric.extractPath(at, at + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.dashed != dashed;
}
