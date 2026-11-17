import 'package:flutter/material.dart';

import '../canvas/annotation_controller.dart';

enum EraserMode {
  elementDelete,
  rasterMask,
}

class EraserTool {
  final AnnotationController controller;
  EraserMode mode;
  final double brushRadius;
  final List<Offset> _rasterMaskPoints = [];

  EraserTool(
    this.controller, {
    this.mode = EraserMode.elementDelete,
    this.brushRadius = 10,
  });

  List<Offset> get rasterMaskPoints => List.unmodifiable(_rasterMaskPoints);

  void eraseAt(Offset point) {
    switch (mode) {
      case EraserMode.elementDelete:
        controller.eraseAt(point);
      case EraserMode.rasterMask:
        _rasterMaskPoints.add(point);
    }
  }

  void eraseAlongPath(List<Offset> points) {
    switch (mode) {
      case EraserMode.elementDelete:
        controller.eraseAlongPath(points);
      case EraserMode.rasterMask:
        _rasterMaskPoints.addAll(points);
    }
  }

  List<Offset> commitRasterMask() {
    final result = List<Offset>.from(_rasterMaskPoints);
    _rasterMaskPoints.clear();
    return result;
  }

  void clearRasterMask() {
    _rasterMaskPoints.clear();
  }
}
