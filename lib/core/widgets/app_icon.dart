import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

/// An icon described by SVG path data on a square view box: a line drawing
/// by default, or a solid shape when [filled].
@immutable
class AppIconData {
  const AppIconData(this.path, {this.viewBox = 24, this.filled = false});

  final String path;
  final double viewBox;
  final bool filled;
}

/// The NorbuFlow icon set. Deliberately plain line drawings: the design keeps
/// sacred imagery away from navigation, deletes and errors, so the Offerings
/// tab is a simple bowl rather than a lotus.
abstract final class AppIcons {
  static const addPerson = AppIconData(
    'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21c0-4 3-7 7-7s7 3 7 7M19 8v6M16 11h6',
  );
  static const renew = AppIconData('M20 12a8 8 0 1 1-2.3-5.7M20 4v4h-4');
  static const lamp = AppIconData(
    'M12 3c2 3 2 5 0 6-2-1-2-3 0-6zM6 12h12l-1.5 4h-9zM9 16l-1 5h8l-1-5',
  );
  static const receipt = AppIconData(
    'M6 2h12v20l-3-2-3 2-3-2-3 2zM9 7h6M9 11h6M9 15h4',
  );
  static const calendar = AppIconData('M4 6h16v15H4zM4 10h16M8 3v5M16 3v5');
  static const calendarDays = AppIconData(
    'M4 6h16v15H4zM4 10h16M8 3v5M16 3v5M8 14h2M14 14h2M8 17h2',
  );
  static const announce = AppIconData(
    'M3 10v4h4l6 4V6l-6 4zM16 9a4 4 0 0 1 0 6M19 6a8 8 0 0 1 0 12',
  );
  static const home = AppIconData('M3 11l9-7 9 7v10h-6v-6H9v6H3z');
  static const members = AppIconData(
    'M8 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM1.5 20c0-3.5 3-6 6.5-6s6.5 2.5 6.5 6M16 4a3.5 3.5 0 0 1 0 7M18 14c2.5.5 4.5 2.8 4.5 6',
  );
  static const bowl = AppIconData('M3 11h18a9 9 0 0 1-18 0zM8 20h8');
  static const more = AppIconData(
    'M4 12a1 1 0 1 0 2 0 1 1 0 0 0-2 0M11 12a1 1 0 1 0 2 0 1 1 0 0 0-2 0M18 12a1 1 0 1 0 2 0 1 1 0 0 0-2 0',
  );
  static const qr = AppIconData(
    'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2v2h-2zM18 18h2v2h-2zM14 18h2M18 14h2',
  );
  static const print = AppIconData(
    'M6 9V3h12v6M6 18H3v-8h18v8h-3M6 14h12v7H6z',
  );
  static const mail = AppIconData('M3 5h18v14H3zM3 6l9 7 9-7');
  static const chat = AppIconData('M4 20l1.5-4A8 8 0 1 1 8 19z');
  static const letter = AppIconData('M4 4h16v16H4zM8 9h8M8 13h8M8 17h5');
  static const hours = AppIconData(
    'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
  );
  static const chart = AppIconData('M4 20V10M10 20V4M16 20v-7M22 20H2');
  static const bundle = AppIconData('M4 7h16v13H4zM8 7V4h8v3M8 12h8');
  static const check = AppIconData('M5 12l5 5 9-10');
  static const document = AppIconData(
    'M6 2h9l5 5v15H6zM14 2v6h6M9 13h8M9 17h8',
  );
  static const idCard = AppIconData(
    'M3 5h18v14H3zM7 10a2 2 0 1 0 4 0 2 2 0 0 0-4 0M5.5 16c.6-1.6 1.9-2.5 3.5-2.5s2.9.9 3.5 2.5M14 9h4M14 13h4',
  );
  static const heart = AppIconData(
    'M12 20s-7-4.4-7-9.6A4 4 0 0 1 12 8a4 4 0 0 1 7 2.4C19 15.6 12 20 12 20z',
  );
  static const bell = AppIconData(
    'M6 17h12l-1.5-2v-5a4.5 4.5 0 0 0-9 0v5zM10 20h4M12 3v2',
  );
  static const building = AppIconData(
    'M3 21h18M5 21V10l7-5 7 5v11M10 21v-5h4v5',
  );
  static const plus = AppIconData('M12 5v14M5 12h14');
  static const search = AppIconData(
    'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM21 21l-5-5',
  );
  static const lock = AppIconData(
    'M6 11V8a6 6 0 0 1 12 0v3M5 11h14v10H5zM12 15v2',
  );
  static const camera = AppIconData(
    'M4 8h3l2-3h6l2 3h3v12H4zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  );
  static const image = AppIconData(
    'M3 4h18v16H3zM3 16l5-5 4 4 3-3 6 6M15.5 9a1.5 1.5 0 1 0 0-.01',
  );
  static const person = AppIconData(
    'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4.5 21c.8-4 3.8-6.5 7.5-6.5s6.7 2.5 7.5 6.5',
  );
  static const share = AppIconData('M12 3v12M7 8l5-5 5 5M5 14v6h14v-6');
  static const download = AppIconData('M12 3v12M7 10l5 5 5-5M5 20h14');
  static const sparkle = AppIconData(
    'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 16l.8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8z',
  );
  static const sliders = AppIconData(
    'M4 6h16M4 12h16M4 18h16M8 4v4M16 10v4M10 16v4',
  );
  static const swap = AppIconData('M7 7h13l-3-3M17 17H4l3 3');
  static const turnLeft = AppIconData('M4 12a8 8 0 1 0 2.3-5.7M4 4v4h4');
  static const turnRight = AppIconData('M20 12a8 8 0 1 1-2.3-5.7M20 4v4h-4');
  static const flip = AppIconData('M12 3v18M8 7l-5 5 5 5zM16 7l5 5-5 5z');
  static const alert = AppIconData('M12 5v9M12 18.5v.01');
  static const minus = AppIconData('M6 12h12');
  static const arrowUp = AppIconData('M12 19V5M6 11l6-6 6 6');
  static const arrowDown = AppIconData('M12 5v14M6 13l6 6 6-6');
  static const bold = AppIconData(
    'M7 4h6a4 4 0 0 1 0 8H7zM7 12h7a4 4 0 0 1 0 8H7z',
  );
  static const italic = AppIconData('M10 4h8M6 20h8M14 4l-4 16');
  static const underline = AppIconData('M7 4v7a5 5 0 0 0 10 0V4M5 20h14');
  static const bulletList = AppIconData(
    'M9 6h11M9 12h11M9 18h11M4.5 6v.01M4.5 12v.01M4.5 18v.01',
  );
  static const paste = AppIconData(
    'M8 5H6v16h12V5h-2M9 3h6v4H9zM9 12h6M9 16h4',
  );

  // Practice-day marks. Drawn rather than typed as symbols (◆ ✦ ● ❖ ○)
  // because the app's fonts do not contain them, and what a device
  // substitutes varies.
  static const diamond = AppIconData('M12 3l7 9-7 9-7-9z', filled: true);
  static const star = AppIconData(
    'M12 2l2.6 7.4L22 12l-7.4 2.6L12 22l-2.6-7.4L2 12l7.4-2.6z',
    filled: true,
  );
  static const disc = AppIconData(
    'M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16z',
    filled: true,
  );
  static const quadDiamond = AppIconData(
    'M12 2l4 4-4 4-4-4zM18 8l4 4-4 4-4-4zM6 8l4 4-4 4-4-4zM12 14l4 4-4 4-4-4z',
    filled: true,
  );
  static const ring = AppIconData('M12 5a7 7 0 1 0 0 14 7 7 0 0 0 0-14z');

  static const chevronLeft = AppIconData('M15 5l-7 7 7 7');
  static const chevronRight = AppIconData('M9 5l7 7-7 7');
  static const chevronDown = AppIconData('M6 9l6 6 6-6');
  static const paperclip = AppIconData(
    'M20 11l-8.5 8.5a5 5 0 0 1-7-7L13 4a3.5 3.5 0 0 1 5 5l-8.5 8.5a2 2 0 0 1-3-3L14 7',
  );

  /// The NorbuFlow jewel, drawn on a 64-unit box.
  static const jewelOutline = AppIconData(
    'M32 6 52 24 32 58 12 24Z',
    viewBox: 64,
  );
  static const jewelFacets = AppIconData(
    'M12 24h40M22 24l10-18 10 18M22 24l10 34 10-34',
    viewBox: 64,
  );
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 1.8,
  });

  final AppIconData icon;
  final double size;
  final Color? color;

  /// Stroke width in view-box units, so it scales with [size].
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _IconPainter(
          icon: icon,
          color: color ?? IconTheme.of(context).color ?? Colors.black,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

/// The NorbuFlow jewel mark.
class JewelLogo extends StatelessWidget {
  const JewelLogo({
    super.key,
    required this.size,
    required this.color,
    this.fill,
    this.strokeWidth = 1.6,
  });

  final double size;
  final Color color;
  final Color? fill;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _IconPainter(
          icon: AppIcons.jewelOutline,
          overlay: AppIcons.jewelFacets,
          color: color,
          fill: fill,
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.butt,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
    this.overlay,
    this.fill,
    this.strokeCap = StrokeCap.round,
  });

  // Parsing SVG path data is not free; each icon is parsed once.
  static final Map<String, Path> _cache = {};

  final AppIconData icon;
  final AppIconData? overlay;
  final Color color;
  final Color? fill;
  final double strokeWidth;
  final StrokeCap strokeCap;

  static Path _pathFor(AppIconData data) =>
      _cache.putIfAbsent(data.path, () => parseSvgPathData(data.path));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / icon.viewBox);
    final path = _pathFor(icon);
    if (icon.filled) {
      canvas.drawPath(path, Paint()..color = color);
      return;
    }
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!);
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = strokeCap
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);
    if (overlay != null) canvas.drawPath(_pathFor(overlay!), stroke);
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.fill != fill ||
      oldDelegate.strokeWidth != strokeWidth;
}
