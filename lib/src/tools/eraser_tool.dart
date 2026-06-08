import 'package:flutter/material.dart';

import '../canvas/annotation_controller.dart';

class EraserTool {
  final AnnotationController controller;

  const EraserTool(this.controller);

  void eraseAt(Offset point) {
    controller.eraseAt(point);
  }

  void eraseAlongPath(List<Offset> points) {
    controller.eraseAlongPath(points);
  }
}
