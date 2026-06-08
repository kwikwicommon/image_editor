import 'dart:math';

import 'package:flutter/material.dart';

import 'background_state.dart';

class PatternPainter extends CustomPainter {
  final PatternPreset preset;
  final Color color;
  final Color backgroundColor;
  final double scale;

  const PatternPainter({
    required this.preset,
    required this.color,
    required this.backgroundColor,
    required this.scale,
  });

  factory PatternPainter.fromState(BackgroundState state) {
    final safeState = state.normalized();
    return PatternPainter(
      preset: safeState.patternPreset,
      color: safeState.patternColor,
      backgroundColor: safeState.patternBackgroundColor,
      scale: safeState.patternScale,
    );
  }

  static void paintPattern(
    Canvas canvas,
    Size size, {
    required PatternPreset preset,
    required Color color,
    required Color backgroundColor,
    required double scale,
  }) {
    if (!_isPositiveFiniteSize(size)) return;

    final safeScale = _safeScale(scale);
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = safeScale;

    switch (preset) {
      case PatternPreset.grid:
        _drawGrid(canvas, size, paint, safeScale);
        break;
      case PatternPreset.dots:
        _drawDots(canvas, size, color, safeScale);
        break;
      case PatternPreset.diagonalLines:
        _drawDiagonalLines(canvas, size, paint, safeScale);
        break;
      case PatternPreset.crosshatch:
        _drawDiagonalLines(canvas, size, paint, safeScale);
        _drawReverseDiagonalLines(canvas, size, paint, safeScale);
        break;
      case PatternPreset.hexagons:
        _drawHexagons(canvas, size, paint, safeScale);
        break;
      case PatternPreset.waves:
        _drawWaves(canvas, size, paint, safeScale);
        break;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintPattern(
      canvas,
      size,
      preset: preset,
      color: color,
      backgroundColor: backgroundColor,
      scale: scale,
    );
  }

  static void _drawGrid(Canvas canvas, Size size, Paint paint, double scale) {
    final step = 24.0 * scale;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  static void _drawDots(Canvas canvas, Size size, Color color, double scale) {
    final step = 18.0 * scale;
    final radius = 1.8 * scale;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = step / 2; x <= size.width; x += step) {
      for (double y = step / 2; y <= size.height; y += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  static void _drawDiagonalLines(
    Canvas canvas,
    Size size,
    Paint paint,
    double scale,
  ) {
    final step = 18.0 * scale;
    for (double x = -size.height; x <= size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  static void _drawReverseDiagonalLines(
    Canvas canvas,
    Size size,
    Paint paint,
    double scale,
  ) {
    final step = 18.0 * scale;
    for (double x = 0; x <= size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  static void _drawHexagons(
    Canvas canvas,
    Size size,
    Paint paint,
    double scale,
  ) {
    final radius = 12.0 * scale;
    final height = sqrt(3) * radius;
    var column = 0;

    for (double x = -radius; x <= size.width + radius; x += radius * 1.5) {
      final yOffset = column.isOdd ? height / 2 : 0.0;
      for (double y = -height; y <= size.height + height; y += height) {
        canvas.drawPath(_hexagonPath(Offset(x, y + yOffset), radius), paint);
      }
      column += 1;
    }
  }

  static Path _hexagonPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i += 1) {
      final angle = pi / 6 + i * pi / 3;
      final point = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  static void _drawWaves(Canvas canvas, Size size, Paint paint, double scale) {
    final gap = 18.0 * scale;
    final amplitude = 4.0 * scale;
    final wavelength = 32.0 * scale;

    for (double y = gap / 2; y <= size.height + gap; y += gap) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width + wavelength; x += wavelength) {
        path.relativeQuadraticBezierTo(
          wavelength / 4,
          -amplitude,
          wavelength / 2,
          0,
        );
        path.relativeQuadraticBezierTo(
          wavelength / 4,
          amplitude,
          wavelength / 2,
          0,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  static double _safeScale(double scale) {
    final finiteScale = scale.isFinite ? scale : 1.0;
    return finiteScale
        .clamp(BackgroundState.minPatternScale, BackgroundState.maxPatternScale)
        .toDouble();
  }

  @override
  bool shouldRepaint(covariant PatternPainter oldDelegate) {
    return preset != oldDelegate.preset ||
        color != oldDelegate.color ||
        backgroundColor != oldDelegate.backgroundColor ||
        scale != oldDelegate.scale;
  }

  static bool _isPositiveFiniteSize(Size size) {
    return size.width.isFinite &&
        size.height.isFinite &&
        size.width > 0 &&
        size.height > 0;
  }
}
