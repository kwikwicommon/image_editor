import 'package:flutter/material.dart';

/// Background display modes for the annotation canvas.
/// These control how the canvas background appears during editing
/// without mixing display background into export pixels.
enum CanvasDisplayMode {
  checkerboard,
  white,
  black,
  custom,
}

class CanvasDisplayConfig {
  final CanvasDisplayMode mode;
  final Color? customColor;
  final double checkerSize;
  final Color checkerLight;
  final Color checkerDark;

  const CanvasDisplayConfig({
    this.mode = CanvasDisplayMode.checkerboard,
    this.customColor,
    this.checkerSize = 8.0,
    this.checkerLight = const Color(0xFFFFFFFF),
    this.checkerDark = const Color(0xFFE0E0E0),
  });

  Color get effectiveBackgroundColor {
    switch (mode) {
      case CanvasDisplayMode.white:
        return const Color(0xFFFFFFFF);
      case CanvasDisplayMode.black:
        return const Color(0xFF000000);
      case CanvasDisplayMode.custom:
        return customColor ?? const Color(0xFFFFFFFF);
      case CanvasDisplayMode.checkerboard:
        return const Color(0x00000000);
    }
  }

  bool get isCheckerboard => mode == CanvasDisplayMode.checkerboard;

  void paintBackground(Canvas canvas, Size size) {
    if (isCheckerboard) {
      _paintCheckerboard(canvas, size);
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = effectiveBackgroundColor,
      );
    }
  }

  void _paintCheckerboard(Canvas canvas, Size size) {
    final p1 = Paint()..color = checkerLight;
    final p2 = Paint()..color = checkerDark;
    for (double y = 0; y < size.height; y += checkerSize) {
      for (double x = 0; x < size.width; x += checkerSize) {
        final isEven = ((x / checkerSize).floor() + (y / checkerSize).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, checkerSize, checkerSize),
          isEven ? p1 : p2,
        );
      }
    }
  }
}
