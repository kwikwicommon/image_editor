import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import '../core/serialization_utils.dart';
import 'annotation_hit_testing.dart';
import 'annotation_json.dart';
import 'annotation_painter.dart';

const _uuid = Uuid();

/// Base class for all annotation elements
abstract class AnnotationElement {
  final String id;
  final Offset position;
  final double rotation;
  final double scale;
  final int zIndex;
  final bool isLocked;
  final bool isVisible;

  /// Geometry-bearing elements derive this from their concrete geometry.
  /// Point-positioned elements, such as text and counters, use it directly.
  AnnotationElement({
    String? id,
    this.position = Offset.zero,
    this.rotation = 0,
    this.scale = 1.0,
    this.zIndex = 0,
    this.isLocked = false,
    this.isVisible = true,
  }) : id = id ?? _uuid.v4();

  Rect get geometryBounds;
  Rect get bounds => _transformedBounds(geometryBounds, rotation, scale);
  void paint(Canvas canvas, Size size);
  bool hitTest(Offset point);
  AnnotationElement clone({bool preserveId = true});
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  });
  Map<String, dynamic> toJson();
}

Map<String, dynamic> baseElementToJson(AnnotationElement element) {
  return {
    'id': element.id,
    'position': offsetToJson(element.position),
    'rotation': element.rotation,
    'scale': element.scale,
    'zIndex': element.zIndex,
    'isLocked': element.isLocked,
    'isVisible': element.isVisible,
  };
}

Offset _rectGeometryAnchor(Rect rect) => rect.topLeft;

Offset _pointsGeometryAnchor(Iterable<Offset> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) return Offset.zero;
  var minX = iterator.current.dx;
  var minY = iterator.current.dy;
  while (iterator.moveNext()) {
    minX = min(minX, iterator.current.dx);
    minY = min(minY, iterator.current.dy);
  }
  return Offset(minX, minY);
}

Rect _pointsGeometryBounds(Iterable<Offset> points) {
  final iterator = points.iterator;
  if (!iterator.moveNext()) return Rect.zero;
  var minX = iterator.current.dx;
  var minY = iterator.current.dy;
  var maxX = iterator.current.dx;
  var maxY = iterator.current.dy;
  while (iterator.moveNext()) {
    minX = min(minX, iterator.current.dx);
    minY = min(minY, iterator.current.dy);
    maxX = max(maxX, iterator.current.dx);
    maxY = max(maxY, iterator.current.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

Offset _arrowGeometryAnchor(
  Offset startPoint,
  Offset endPoint,
  Offset? controlPoint,
) {
  final points = [startPoint, endPoint, if (controlPoint != null) controlPoint];
  return _pointsGeometryAnchor(points);
}

Rect _transformedBounds(Rect rect, double rotation, double scale) {
  if (rect.isEmpty || (rotation == 0 && scale == 1.0)) return rect;
  final transformed = [
    _transformPoint(rect.topLeft, rect.center, rotation, scale),
    _transformPoint(rect.topRight, rect.center, rotation, scale),
    _transformPoint(rect.bottomLeft, rect.center, rotation, scale),
    _transformPoint(rect.bottomRight, rect.center, rotation, scale),
  ];
  return Rect.fromLTRB(
    transformed.map((point) => point.dx).reduce(min),
    transformed.map((point) => point.dy).reduce(min),
    transformed.map((point) => point.dx).reduce(max),
    transformed.map((point) => point.dy).reduce(max),
  );
}

Offset _transformPoint(
  Offset point,
  Offset center,
  double rotation,
  double scale,
) {
  final safeScale = scale.abs() < 0.001 ? 1.0 : scale;
  final translated = (point - center) * safeScale;
  if (rotation == 0) return center + translated;
  final cosValue = cos(rotation);
  final sinValue = sin(rotation);
  return Offset(
    center.dx + translated.dx * cosValue - translated.dy * sinValue,
    center.dy + translated.dx * sinValue + translated.dy * cosValue,
  );
}

Offset inverseTransformPoint(
  Offset point,
  Offset center,
  double rotation,
  double scale,
) {
  final safeScale = scale.abs() < 0.001 ? 1.0 : scale;
  final translated = point - center;
  final cosValue = cos(-rotation);
  final sinValue = sin(-rotation);
  final rotated = Offset(
    translated.dx * cosValue - translated.dy * sinValue,
    translated.dx * sinValue + translated.dy * cosValue,
  );
  return center + rotated / safeScale;
}

/// Arrow type
enum ArrowType { straight, curved, doubleSided }

/// Arrow element
class ArrowElement extends AnnotationElement {
  final Offset startPoint;
  final Offset endPoint;
  final Offset? controlPoint;
  final Color color;
  final double strokeWidth;
  final ArrowHeadStyle headStyle;
  final ArrowType arrowType;
  final bool isDashed;

  ArrowElement({
    String? id,
    required this.startPoint,
    required this.endPoint,
    this.controlPoint,
    this.color = Colors.red,
    this.strokeWidth = 2.0,
    this.headStyle = ArrowHeadStyle.filled,
    this.arrowType = ArrowType.straight,
    this.isDashed = false,
    double rotation = 0,
    double scale = 1.0,
    int zIndex = 0,
    bool isLocked = false,
    bool isVisible = true,
  }) : super(
         id: id,
         position: _arrowGeometryAnchor(startPoint, endPoint, controlPoint),
         rotation: rotation,
         scale: scale,
         zIndex: zIndex,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Rect get geometryBounds {
    final bounds = _pointsGeometryBounds([
      startPoint,
      endPoint,
      if (controlPoint != null) controlPoint!,
    ]);
    return bounds.inflate(strokeWidth + 14);
  }

  @override
  void paint(Canvas canvas, Size size) {
    AnnotationElementPainter.paint(this, canvas, size);
  }

  @override
  bool hitTest(Offset point) {
    return AnnotationElementHitTester.hitTest(this, point);
  }

  @override
  AnnotationElement clone({bool preserveId = true}) =>
      translated(Offset.zero, preserveId: preserveId);

  @override
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  }) => ArrowElement(
    id: preserveId ? id : null,
    startPoint: startPoint + offset,
    endPoint: endPoint + offset,
    controlPoint: controlPoint == null ? null : controlPoint! + offset,
    color: color,
    strokeWidth: strokeWidth,
    headStyle: headStyle,
    arrowType: arrowType,
    isDashed: isDashed,
    rotation: rotation,
    scale: scale,
    zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked,
    isVisible: isVisible,
  );

  @override
  Map<String, dynamic> toJson() => AnnotationElementJson.toJson(this);
}

enum ArrowHeadStyle { filled, hollow, diamond, circle }

/// Rectangle / shape element
class ShapeElement extends AnnotationElement {
  final Rect rect;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  final double cornerRadius;
  final ShapeType shapeType;
  final bool isDashed;

  ShapeElement({
    String? id,
    required this.rect,
    this.strokeColor = Colors.red,
    this.fillColor,
    this.strokeWidth = 2.0,
    this.cornerRadius = 0,
    this.shapeType = ShapeType.rectangle,
    this.isDashed = false,
    double rotation = 0,
    double scale = 1.0,
    int zIndex = 0,
    bool isLocked = false,
    bool isVisible = true,
  }) : super(
         id: id,
         position: _rectGeometryAnchor(rect),
         rotation: rotation,
         scale: scale,
         zIndex: zIndex,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Rect get geometryBounds => rect.inflate(strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    AnnotationElementPainter.paint(this, canvas, size);
  }

  @override
  bool hitTest(Offset point) {
    return AnnotationElementHitTester.hitTest(this, point);
  }

  @override
  AnnotationElement clone({bool preserveId = true}) =>
      translated(Offset.zero, preserveId: preserveId);

  @override
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  }) => ShapeElement(
    id: preserveId ? id : null,
    rect: rect.shift(offset),
    strokeColor: strokeColor,
    fillColor: fillColor,
    strokeWidth: strokeWidth,
    cornerRadius: cornerRadius,
    shapeType: shapeType,
    isDashed: isDashed,
    rotation: rotation,
    scale: scale,
    zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked,
    isVisible: isVisible,
  );

  @override
  Map<String, dynamic> toJson() => AnnotationElementJson.toJson(this);
}

enum ShapeType { rectangle, ellipse, line }

/// Text element
class TextAnnotation extends AnnotationElement {
  final String text;
  final Color textColor;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? backgroundColor;
  final TextStyle? style;
  final double maxWidth;

  TextAnnotation({
    super.id,
    required this.text,
    required super.position,
    this.textColor = Colors.white,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.backgroundColor,
    this.style,
    this.maxWidth = 300,
    super.rotation,
    super.scale,
    super.zIndex,
    super.isLocked,
    super.isVisible,
  });

  @override
  Rect get geometryBounds {
    final tp = AnnotationElementPainter.buildTextPainter(this);
    tp.layout(maxWidth: maxWidth);
    return Rect.fromLTWH(
      position.dx - 4,
      position.dy - 2,
      tp.width + 16,
      tp.height + 8,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    AnnotationElementPainter.paint(this, canvas, size);
  }

  @override
  bool hitTest(Offset point) => AnnotationElementHitTester.hitTest(this, point);

  @override
  AnnotationElement clone({bool preserveId = true}) =>
      translated(Offset.zero, preserveId: preserveId);

  @override
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  }) => TextAnnotation(
    id: preserveId ? id : null,
    text: text,
    position: position + offset,
    textColor: textColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    backgroundColor: backgroundColor,
    style: style,
    maxWidth: maxWidth,
    rotation: rotation,
    scale: scale,
    zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked,
    isVisible: isVisible,
  );

  @override
  Map<String, dynamic> toJson() => AnnotationElementJson.toJson(this);
}

/// Free draw (pencil/highlighter) element
class FreeDrawElement extends AnnotationElement {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  FreeDrawElement({
    String? id,
    required List<Offset> points,
    this.color = Colors.red,
    this.strokeWidth = 2.0,
    this.isHighlighter = false,
    double rotation = 0,
    double scale = 1.0,
    int zIndex = 0,
    bool isLocked = false,
    bool isVisible = true,
  }) : points = List.unmodifiable(points),
       super(
         id: id,
         position: _pointsGeometryAnchor(points),
         rotation: rotation,
         scale: scale,
         zIndex: zIndex,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Rect get geometryBounds {
    if (points.isEmpty) return Rect.zero;
    double minX = double.infinity,
        minY = double.infinity,
        maxX = -double.infinity,
        maxY = -double.infinity;
    for (final p in points) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(strokeWidth);
  }

  @override
  void paint(Canvas canvas, Size size) {
    AnnotationElementPainter.paint(this, canvas, size);
  }

  @override
  bool hitTest(Offset point) {
    return AnnotationElementHitTester.hitTest(this, point);
  }

  @override
  AnnotationElement clone({bool preserveId = true}) =>
      translated(Offset.zero, preserveId: preserveId);

  @override
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  }) => FreeDrawElement(
    id: preserveId ? id : null,
    points: points.map((point) => point + offset).toList(),
    color: color,
    strokeWidth: strokeWidth,
    isHighlighter: isHighlighter,
    rotation: rotation,
    scale: scale,
    zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked,
    isVisible: isVisible,
  );

  @override
  Map<String, dynamic> toJson() => AnnotationElementJson.toJson(this);
}

/// Blur/mosaic element
class BlurElement extends AnnotationElement {
  final Rect rect;
  final BlurMode blurMode;
  final double intensity;

  BlurElement({
    String? id,
    required this.rect,
    this.blurMode = BlurMode.mosaic,
    this.intensity = 10,
    double rotation = 0,
    double scale = 1.0,
    int zIndex = 0,
    bool isLocked = false,
    bool isVisible = true,
  }) : super(
         id: id,
         position: _rectGeometryAnchor(rect),
         rotation: rotation,
         scale: scale,
         zIndex: zIndex,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Rect get geometryBounds => rect;

  @override
  void paint(Canvas canvas, Size size) {
    AnnotationElementPainter.paint(this, canvas, size);
  }

  void paintMosaic(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    final blockSize = intensity.clamp(4.0, 20.0);
    final random = Random(rect.hashCode);

    for (double x = rect.left; x < rect.right; x += blockSize) {
      for (double y = rect.top; y < rect.bottom; y += blockSize) {
        paint.color = Color.fromARGB(
          200,
          random.nextInt(200) + 55,
          random.nextInt(200) + 55,
          random.nextInt(200) + 55,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            y,
            min(blockSize, rect.right - x),
            min(blockSize, rect.bottom - y),
          ),
          paint,
        );
      }
    }

    final borderPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, borderPaint);
  }

  void paintGaussianBlur(Canvas canvas) {
    // Simulate gaussian blur with semi-transparent overlay + blur filter
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.01)
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: intensity,
          sigmaY: intensity,
          tileMode: TileMode.clamp,
        ),
    );
    // Add a frosted glass effect
    canvas.drawRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.3));
    canvas.restore();

    // Border
    final borderPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, borderPaint);
  }

  void paintSpotlight(Canvas canvas, Size size) {
    // Darken everything except the selected rect
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(
      fullRect,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    // Clear the spotlight area
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.fill,
    );
    canvas.restore();

    // Highlight border
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool hitTest(Offset point) => AnnotationElementHitTester.hitTest(this, point);

  @override
  AnnotationElement clone({bool preserveId = true}) =>
      translated(Offset.zero, preserveId: preserveId);

  @override
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  }) => BlurElement(
    id: preserveId ? id : null,
    rect: rect.shift(offset),
    blurMode: blurMode,
    intensity: intensity,
    rotation: rotation,
    scale: scale,
    zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked,
    isVisible: isVisible,
  );

  @override
  Map<String, dynamic> toJson() => AnnotationElementJson.toJson(this);
}

enum BlurMode { mosaic, gaussianBlur, spotlight }

/// Counter / step number element
class CounterElement extends AnnotationElement {
  final int number;
  final Color color;
  final double size;
  final CounterStyle counterStyle;

  CounterElement({
    super.id,
    required this.number,
    required super.position,
    this.color = Colors.red,
    this.size = 28,
    this.counterStyle = CounterStyle.circle,
    super.rotation,
    super.scale,
    super.zIndex,
    super.isLocked,
    super.isVisible,
  });

  @override
  Rect get geometryBounds =>
      Rect.fromCenter(center: position, width: size, height: size);

  @override
  void paint(Canvas canvas, Size size) {
    AnnotationElementPainter.paint(this, canvas, size);
  }

  @override
  bool hitTest(Offset point) => AnnotationElementHitTester.hitTest(this, point);

  @override
  AnnotationElement clone({bool preserveId = true}) =>
      translated(Offset.zero, preserveId: preserveId);

  @override
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  }) => CounterElement(
    id: preserveId ? id : null,
    number: number,
    position: position + offset,
    color: color,
    size: size,
    counterStyle: counterStyle,
    rotation: rotation,
    scale: scale,
    zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked,
    isVisible: isVisible,
  );

  @override
  Map<String, dynamic> toJson() => AnnotationElementJson.toJson(this);
}

enum CounterStyle { circle, square, diamond }

/// Sticker element - SVG/PNG sticker on canvas
class StickerElement extends AnnotationElement {
  final String? stickerId;
  final String? name;
  final String assetPath;
  final StickerFormat format;
  final Rect rect;
  final Color? tintColor;
  final String? svgContent;
  final String? dataBase64;
  final String? resourceId;
  final String? resourceHash;
  final bool isRecolorable;
  final bool isFlippedH;
  final bool isFlippedV;

  StickerElement({
    String? id,
    this.stickerId,
    this.name,
    required this.assetPath,
    required this.rect,
    this.format = StickerFormat.svg,
    this.tintColor,
    this.svgContent,
    this.dataBase64,
    this.resourceId,
    this.resourceHash,
    this.isRecolorable = true,
    this.isFlippedH = false,
    this.isFlippedV = false,
    double rotation = 0,
    double scale = 1.0,
    int zIndex = 0,
    bool isLocked = false,
    bool isVisible = true,
  }) : super(
         id: id,
         position: _rectGeometryAnchor(rect),
         rotation: rotation,
         scale: scale,
         zIndex: zIndex,
         isLocked: isLocked,
         isVisible: isVisible,
       );

  @override
  Rect get geometryBounds => rect;

  @override
  void paint(Canvas canvas, Size size) {
    AnnotationElementPainter.paint(this, canvas, size);
  }

  void drawSvgPicture(Canvas canvas, PictureInfo pictureInfo) {
    if (rect.isEmpty) return;
    final pictureSize = pictureInfo.size;
    final sourceSize = Size(
      pictureSize.width > 0 ? pictureSize.width : rect.width,
      pictureSize.height > 0 ? pictureSize.height : rect.height,
    );
    final fitted = applyBoxFit(BoxFit.contain, sourceSize, rect.size);
    final sourceRect = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & sourceSize,
    );
    final outputRect = Alignment.center.inscribe(fitted.destination, rect);
    if (sourceRect.width <= 0 ||
        sourceRect.height <= 0 ||
        outputRect.width <= 0 ||
        outputRect.height <= 0) {
      drawFallback(canvas);
      return;
    }

    canvas.save();
    canvas.clipRect(rect);
    canvas.translate(outputRect.left, outputRect.top);
    canvas.scale(
      outputRect.width / sourceRect.width,
      outputRect.height / sourceRect.height,
    );
    canvas.translate(-sourceRect.left, -sourceRect.top);
    canvas.drawPicture(pictureInfo.picture);
    canvas.restore();
  }

  void drawPngImage(Canvas canvas, ui.Image image) {
    if (rect.isEmpty) return;
    final sourceRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.contain, sourceRect.size, rect.size);
    final outputRect = Alignment.center.inscribe(fitted.destination, rect);
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(image, sourceRect, outputRect, paint);
  }

  void drawFallback(Canvas canvas) {
    if (rect.isEmpty) return;
    final borderPaint = Paint()
      ..color = tintColor ?? const Color(0xFF6366F1).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);

    // Draw sticker icon placeholder
    final iconPaint = Paint()
      ..color = tintColor ?? const Color(0xFF6366F1).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final iconSize = rect.shortestSide * 0.3;
    canvas.drawCircle(rect.center, iconSize / 2, iconPaint);
  }

  @override
  bool hitTest(Offset point) {
    return AnnotationElementHitTester.hitTest(this, point);
  }

  @override
  AnnotationElement clone({bool preserveId = true}) =>
      translated(Offset.zero, preserveId: preserveId);

  @override
  AnnotationElement translated(
    Offset offset, {
    bool preserveId = true,
    int? zIndex,
  }) => StickerElement(
    id: preserveId ? id : null,
    stickerId: stickerId,
    name: name,
    assetPath: assetPath,
    rect: rect.shift(offset),
    format: format,
    tintColor: tintColor,
    svgContent: svgContent,
    dataBase64: dataBase64,
    resourceId: resourceId,
    resourceHash: resourceHash,
    isRecolorable: isRecolorable,
    isFlippedH: isFlippedH,
    isFlippedV: isFlippedV,
    rotation: rotation,
    scale: scale,
    zIndex: zIndex ?? this.zIndex,
    isLocked: isLocked,
    isVisible: isVisible,
  );

  @override
  Map<String, dynamic> toJson() => AnnotationElementJson.toJson(this);
}

/// Sticker format
enum StickerFormat { svg, png }
