import 'dart:math';

import 'package:flutter/material.dart';

import 'annotation_element.dart';

class AnnotationElementHitTester {
  const AnnotationElementHitTester._();

  static bool hitTest(AnnotationElement element, Offset point) {
    if (!element.isVisible) return false;
    final localPoint = _localPointForHitTest(element, point);
    if (element is ArrowElement) return _hitTestArrow(element, localPoint);
    if (element is ShapeElement) return _hitTestShape(element, localPoint);
    if (element is TextAnnotation) {
      return element.geometryBounds.contains(localPoint);
    }
    if (element is FreeDrawElement) {
      return _hitTestFreeDraw(element, localPoint);
    }
    if (element is BlurElement) return element.rect.contains(localPoint);
    if (element is CounterElement) {
      return _hitTestCounter(element, localPoint);
    }
    if (element is StickerElement) return element.rect.contains(localPoint);
    return false;
  }

  static Offset _localPointForHitTest(AnnotationElement element, Offset point) {
    if (element.rotation == 0 && element.scale == 1.0) return point;
    return inverseTransformPoint(
      point,
      element.geometryBounds.center,
      element.rotation,
      element.scale,
    );
  }

  static bool _hitTestArrow(ArrowElement element, Offset point) {
    final threshold = max(8.0, element.strokeWidth / 2 + 4);
    if (element.arrowType == ArrowType.curved) {
      final controlPoint = element.controlPoint ?? _defaultControlPoint(element);
      return _distanceToQuadratic(
            point,
            element.startPoint,
            controlPoint,
            element.endPoint,
          ) <=
          threshold;
    }
    return _distanceToSegment(point, element.startPoint, element.endPoint) <=
        threshold;
  }

  static bool _hitTestShape(ShapeElement element, Offset point) {
    final threshold = max(8.0, element.strokeWidth / 2 + 4);
    final rect = _normalizedRect(element.rect);
    switch (element.shapeType) {
      case ShapeType.rectangle:
        if (element.fillColor != null && rect.contains(point)) return true;
        return _rectStrokeContains(rect, point, threshold);
      case ShapeType.ellipse:
        return _ellipseContains(
          rect,
          point,
          threshold,
          filled: element.fillColor != null,
        );
      case ShapeType.line:
        return _distanceToSegment(point, rect.topLeft, rect.bottomRight) <=
            threshold;
    }
  }

  static bool _hitTestFreeDraw(FreeDrawElement element, Offset point) {
    final threshold = max(10.0, element.strokeWidth / 2 + 6);
    if (element.points.isEmpty) return false;
    if (element.points.length == 1) {
      return (point - element.points.first).distance <= threshold;
    }

    for (var index = 0; index < element.points.length - 1; index += 1) {
      if (_distanceToSegment(
            point,
            element.points[index],
            element.points[index + 1],
          ) <=
          threshold) {
        return true;
      }
    }
    return false;
  }

  static bool _hitTestCounter(CounterElement element, Offset point) {
    final halfSize = element.size / 2;
    final delta = point - element.position;
    switch (element.counterStyle) {
      case CounterStyle.circle:
        return delta.distance <= halfSize;
      case CounterStyle.square:
        return Rect.fromCenter(
          center: element.position,
          width: element.size,
          height: element.size,
        ).contains(point);
      case CounterStyle.diamond:
        return delta.dx.abs() + delta.dy.abs() <= halfSize;
    }
  }

  static Offset _defaultControlPoint(ArrowElement element) {
    final dx = element.endPoint.dx - element.startPoint.dx;
    final dy = element.endPoint.dy - element.startPoint.dy;
    final length = sqrt(dx * dx + dy * dy);
    if (length <= 0) return element.startPoint;
    final midpoint = Offset(
      (element.startPoint.dx + element.endPoint.dx) / 2,
      (element.startPoint.dy + element.endPoint.dy) / 2,
    );
    final offsetAmount = length * 0.3;
    return Offset(
      midpoint.dx - dy / length * offsetAmount,
      midpoint.dy + dx / length * offsetAmount,
    );
  }

  static double _distanceToSegment(Offset point, Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared <= 0) return (point - start).distance;
    final t =
        ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) /
        lengthSquared;
    final clampedT = t.clamp(0.0, 1.0).toDouble();
    final closest = Offset(
      start.dx + clampedT * dx,
      start.dy + clampedT * dy,
    );
    return (point - closest).distance;
  }

  static double _distanceToQuadratic(
    Offset point,
    Offset start,
    Offset control,
    Offset end,
  ) {
    var minimumDistance = double.infinity;
    var previous = start;
    const segments = 24;
    for (var index = 1; index <= segments; index += 1) {
      final t = index / segments;
      final current = _quadraticPoint(start, control, end, t);
      minimumDistance = min(
        minimumDistance,
        _distanceToSegment(point, previous, current),
      );
      previous = current;
    }
    return minimumDistance;
  }

  static Offset _quadraticPoint(
    Offset start,
    Offset control,
    Offset end,
    double t,
  ) {
    final inverse = 1 - t;
    return start * (inverse * inverse) +
        control * (2 * inverse * t) +
        end * (t * t);
  }

  static bool _rectStrokeContains(Rect rect, Offset point, double threshold) {
    if (rect.isEmpty) return false;
    final outer = rect.inflate(threshold);
    final inner = rect.deflate(threshold);
    return outer.contains(point) && !inner.contains(point);
  }

  static bool _ellipseContains(
    Rect rect,
    Offset point,
    double threshold, {
    required bool filled,
  }) {
    if (rect.width <= 0 || rect.height <= 0) return false;
    final outerRadiusX = rect.width / 2 + threshold;
    final outerRadiusY = rect.height / 2 + threshold;
    final outerDistance = _ellipseDistance(
      rect.center,
      point,
      outerRadiusX,
      outerRadiusY,
    );
    if (filled) return outerDistance <= 1;

    final innerRadiusX = rect.width / 2 - threshold;
    final innerRadiusY = rect.height / 2 - threshold;
    if (innerRadiusX <= 0 || innerRadiusY <= 0) {
      return outerDistance <= 1;
    }
    final innerDistance = _ellipseDistance(
      rect.center,
      point,
      innerRadiusX,
      innerRadiusY,
    );
    return outerDistance <= 1 && innerDistance >= 1;
  }

  static double _ellipseDistance(
    Offset center,
    Offset point,
    double radiusX,
    double radiusY,
  ) {
    final dx = (point.dx - center.dx) / radiusX;
    final dy = (point.dy - center.dy) / radiusY;
    return dx * dx + dy * dy;
  }

  static Rect _normalizedRect(Rect rect) {
    return Rect.fromLTRB(
      min(rect.left, rect.right),
      min(rect.top, rect.bottom),
      max(rect.left, rect.right),
      max(rect.top, rect.bottom),
    );
  }
}
