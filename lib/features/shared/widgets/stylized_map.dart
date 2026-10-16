import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';

/// Stylized "map" backdrop used behind the client home and driver dashboard.
///
/// A hand-painted vector city (roads, blocks, park, river) with a pulsing
/// user marker — no map SDK or API key required, and it renders offline.
/// When the real maps module lands, swap this widget for the map SDK view;
/// the overlay slots stay identical.
class StylizedMap extends StatefulWidget {
  const StylizedMap({
    super.key,
    this.accent = AppColors.brand,
    this.showPulse = true,
    this.label,
  });

  final Color accent;
  final bool showPulse;
  final String? label;

  @override
  State<StylizedMap> createState() => _StylizedMapState();
}

class _StylizedMapState extends State<StylizedMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _MapPainter(
              accent: widget.accent,
              pulse: _c,
              showPulse: widget.showPulse,
            ),
          ),
        ),
        if (widget.label != null)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 120,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.rPill,
                  boxShadow: AppShadow.soft,
                ),
                child: Text(
                  widget.label!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.accent,
    required this.pulse,
    required this.showPulse,
  }) : super(repaint: pulse);

  final Color accent;
  final Animation<double> pulse;
  final bool showPulse;

  static const _base = Color(0xFFEDEFF4);
  static const _block = Color(0xFFE3E7EF);
  static const _blockAlt = Color(0xFFE9EDF3);
  static const _road = Colors.white;
  static const _roadMinor = Color(0xFFF7F9FC);
  static const _park = Color(0xFFDDF2E5);
  static const _water = Color(0xFFD6E7F7);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _base);
    _paintBlocks(canvas, size);
    _paintParkAndWater(canvas, size);
    _paintRoads(canvas, size);
    if (showPulse) _paintMarker(canvas, size);
  }

  void _paintBlocks(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint();
    const cell = 92.0;
    for (double x = -20; x < size.width + cell; x += cell) {
      for (double y = -20; y < size.height + cell; y += cell) {
        final w = cell - 14 - rnd.nextDouble() * 10;
        final h = cell - 14 - rnd.nextDouble() * 14;
        paint.color = rnd.nextBool() ? _block : _blockAlt;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 7, y + 7, w, h),
            const Radius.circular(6),
          ),
          paint,
        );
      }
    }
  }

  void _paintParkAndWater(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .58, size.height * .1, 150, 120),
        const Radius.circular(18),
      ),
      Paint()..color = _park,
    );
    final path = Path()
      ..moveTo(-20, size.height * .82)
      ..cubicTo(
        size.width * .25,
        size.height * .72,
        size.width * .45,
        size.height * .95,
        size.width + 20,
        size.height * .78,
      )
      ..lineTo(size.width + 20, size.height * .86)
      ..cubicTo(
        size.width * .45,
        size.height * 1.03,
        size.width * .25,
        size.height * .80,
        -20,
        size.height * .90,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = _water);
  }

  void _paintRoads(Canvas canvas, Size size) {
    final major = Paint()
      ..color = _road
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final minor = Paint()
      ..color = _roadMinor
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(-10, size.height * .38),
      Offset(size.width + 10, size.height * .34),
      major,
    );
    canvas.drawLine(
      Offset(size.width * .30, -10),
      Offset(size.width * .36, size.height + 10),
      major,
    );
    canvas.drawLine(
      Offset(-10, size.height * .66),
      Offset(size.width + 10, size.height * .70),
      major,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-10, size.height * 1.05)
        ..lineTo(size.width + 10, -10),
      major,
    );

    for (double y = .14; y < 1; y += .17) {
      canvas.drawLine(
        Offset(-10, size.height * y),
        Offset(size.width + 10, size.height * (y + .015)),
        minor,
      );
    }
    for (double x = .14; x < 1; x += .2) {
      canvas.drawLine(
        Offset(size.width * x, -10),
        Offset(size.width * (x + .02), size.height + 10),
        minor,
      );
    }
  }

  void _paintMarker(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .52);

    final route = Paint()
      ..color = accent
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy)
        ..cubicTo(
          center.dx + 60,
          center.dy - 70,
          center.dx + 130,
          center.dy + 40,
          center.dx + 190,
          center.dy - 30,
        ),
      route,
    );

    final t = pulse.value;
    canvas.drawCircle(
      center,
      26 + 34 * t,
      Paint()..color = accent.withValues(alpha: .28 * (1 - t)),
    );
    canvas.drawCircle(center, 13, Paint()..color = Colors.white);
    canvas.drawCircle(center, 9, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.accent != accent || old.showPulse != showPulse;
}
