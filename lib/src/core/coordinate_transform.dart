import 'dart:math';
import 'dart:ui';

/// Unified coordinate transform API for converting between
/// image coordinates, view coordinates, and device pixel coordinates.
/// Handles zoom, pan, rotation, DPR, and hit testing semantics.
class CoordinateTransform {
  final Size imageSize;
  final Size viewSize;
  final double zoom;
  final Offset pan;
  final double rotation;
  final double devicePixelRatio;

  const CoordinateTransform({
    required this.imageSize,
    required this.viewSize,
    this.zoom = 1.0,
    this.pan = Offset.zero,
    this.rotation = 0,
    this.devicePixelRatio = 1.0,
  });

  double get fitScale {
    if (imageSize.isEmpty || viewSize.isEmpty) return 1.0;
    final sx = viewSize.width / imageSize.width;
    final sy = viewSize.height / imageSize.height;
    return min(sx, sy);
  }

  double get fillScale {
    if (imageSize.isEmpty || viewSize.isEmpty) return 1.0;
    final sx = viewSize.width / imageSize.width;
    final sy = viewSize.height / imageSize.height;
    return max(sx, sy);
  }

  double get effectiveScale => zoom;

  Offset get imageCenter =>
      Offset(imageSize.width / 2, imageSize.height / 2);

  Offset get viewCenter =>
      Offset(viewSize.width / 2, viewSize.height / 2);

  /// Convert a point in view (widget) coordinates to image coordinates.
  Offset viewToImage(Offset viewPoint) {
    final centered = viewPoint - viewCenter - pan;
    final rotated = _rotatePoint(centered, -rotation);
    final scaled = rotated / effectiveScale;
    return scaled + imageCenter;
  }

  /// Convert a point in image coordinates to view (widget) coordinates.
  Offset imageToView(Offset imagePoint) {
    final centered = imagePoint - imageCenter;
    final scaled = centered * effectiveScale;
    final rotated = _rotatePoint(scaled, rotation);
    return rotated + viewCenter + pan;
  }

  /// Convert a point in view coordinates to device pixel coordinates.
  Offset viewToDevice(Offset viewPoint) {
    return viewPoint * devicePixelRatio;
  }

  /// Convert a point in device pixel coordinates to view coordinates.
  Offset deviceToView(Offset devicePoint) {
    return devicePoint / devicePixelRatio;
  }

  /// Convert a point in image coordinates to device pixel coordinates.
  Offset imageToDevice(Offset imagePoint) {
    return viewToDevice(imageToView(imagePoint));
  }

  /// Convert a point in device pixel coordinates to image coordinates.
  Offset deviceToImage(Offset devicePoint) {
    return viewToImage(deviceToView(devicePoint));
  }

  /// Convert a rectangle in image coordinates to view coordinates.
  Rect imageRectToView(Rect imageRect) {
    final tl = imageToView(imageRect.topLeft);
    final br = imageToView(imageRect.bottomRight);
    return Rect.fromPoints(tl, br);
  }

  /// Convert a rectangle in view coordinates to image coordinates.
  Rect viewRectToImage(Rect viewRect) {
    final tl = viewToImage(viewRect.topLeft);
    final br = viewToImage(viewRect.bottomRight);
    return Rect.fromPoints(tl, br);
  }

  /// Hit test threshold in image coordinates (accounts for zoom + DPR).
  double hitTestThreshold({double viewThreshold = 10}) {
    return viewThreshold / effectiveScale;
  }

  Offset _rotatePoint(Offset point, double angle) {
    if (angle == 0) return point;
    final c = cos(angle);
    final s = sin(angle);
    return Offset(
      point.dx * c - point.dy * s,
      point.dx * s + point.dy * c,
    );
  }

  CoordinateTransform copyWith({
    Size? imageSize,
    Size? viewSize,
    double? zoom,
    Offset? pan,
    double? rotation,
    double? devicePixelRatio,
  }) {
    return CoordinateTransform(
      imageSize: imageSize ?? this.imageSize,
      viewSize: viewSize ?? this.viewSize,
      zoom: zoom ?? this.zoom,
      pan: pan ?? this.pan,
      rotation: rotation ?? this.rotation,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }
}
