import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Path of an eight-pointed star (khatam), the classic Islamic geometric motif.
Path eightPointStar(Offset c, double r, {double inner = 0.765}) {
  final path = Path();
  for (var k = 0; k < 16; k++) {
    final a = -math.pi / 2 + k * math.pi / 8;
    final rad = k.isEven ? r : r * inner;
    final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

/// Draws a repeating geometric pattern: eight-pointed stars on a grid,
/// small diamonds between them and thin lines joining the stars.
class IslamicPatternPainter extends CustomPainter {
  IslamicPatternPainter({required this.color, this.opacity = 0.08, this.cell = 56});

  final Color color;
  final double opacity;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..isAntiAlias = true;
    final r = cell * 0.34;
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    for (var i = 0; i <= cols; i++) {
      for (var j = 0; j <= rows; j++) {
        final c = Offset(i * cell, j * cell);
        canvas.drawPath(eightPointStar(c, r), paint);
        canvas.drawPath(eightPointStar(c, r * 0.45), paint);
        // Lines joining neighbouring stars.
        canvas.drawLine(c + Offset(r, 0), c + Offset(cell - r, 0), paint);
        canvas.drawLine(c + Offset(0, r), c + Offset(0, cell - r), paint);
        // Diamond in the gap between four stars.
        final d = c + Offset(cell / 2, cell / 2);
        final s = cell * 0.13;
        canvas.drawPath(
          Path()
            ..moveTo(d.dx, d.dy - s)
            ..lineTo(d.dx + s, d.dy)
            ..lineTo(d.dx, d.dy + s)
            ..lineTo(d.dx - s, d.dy)
            ..close(),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(IslamicPatternPainter old) =>
      old.color != color || old.opacity != opacity || old.cell != cell;
}

/// Fills its area with the geometric pattern.
class PatternLayer extends StatelessWidget {
  const PatternLayer({super.key, required this.color, this.opacity = 0.08, this.cell = 56});

  final Color color;
  final double opacity;
  final double cell;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: IslamicPatternPainter(color: color, opacity: opacity, cell: cell),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app logo: a gold eight-pointed star with a crescent, on emerald.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.withBackground = true});

  final double size;
  final bool withBackground;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LogoPainter(withBackground)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.withBackground);

  final bool withBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    if (withBackground) {
      final rect = Offset.zero & size;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.26)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Brand.greenPattern, Brand.deepEmerald],
          ).createShader(rect),
      );
    }
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Brand.lightGold, Brand.gold],
      ).createShader(Offset.zero & size);

    // Outer star outline.
    canvas.drawPath(
      eightPointStar(c, s * 0.38),
      Paint()
        ..shader = gold.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..strokeJoin = StrokeJoin.round,
    );
    // Soft inner star.
    canvas.drawPath(
      eightPointStar(c, s * 0.29),
      Paint()..color = Brand.onNight.withValues(alpha: 0.10),
    );
    // Crescent: a gold circle with an offset circle cut out.
    final moon = Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.15));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: c + Offset(s * 0.065, -s * 0.035), radius: s * 0.125));
    canvas.drawPath(Path.combine(PathOperation.difference, moon, cut), gold);
    // Small star next to the crescent.
    canvas.drawPath(eightPointStar(c + Offset(s * 0.085, -s * 0.02), s * 0.035, inner: 0.5), gold);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.withBackground != withBackground;
}
