import 'dart:math';

import 'package:flutter/material.dart';

import '../stickers/sticker_render_cache.dart';
import 'annotation_element.dart';

class AnnotationElementPainter {
  const AnnotationElementPainter._();

  static void paint(
    AnnotationElement element,
    Canvas canvas,
    Size size, {
    StickerRenderCache? stickerCache,
  }) {
    if (!element.isVisible) return;

    final applyTransform = element.rotation != 0 || element.scale != 1.0;
    if (applyTransform) {
      final center = element.geometryBounds.center;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(element.rotation);
      canvas.scale(element.scale);
      canvas.translate(-center.dx, -center.dy);
    }

    if (element is ArrowElement) {
      _paintArrow(element, canvas);
    } else if (element is ShapeElement) {
      _paintShape(element, canvas);
    } else if (element is TextAnnotation) {
      _paintText(element, canvas);
    } else if (element is FreeDrawElement) {
      _paintFreeDraw(element, canvas);
    } else if (element is BlurElement) {
      _paintBlur(element, canvas, size);
    } else if (element is CounterElement) {
      _paintCounter(element, canvas);
    } else if (element is StickerElement) {
      _paintSticker(element, canvas, stickerCache);
    }

    if (applyTransform) {
      canvas.restore();
    }
  }

  static void _paintArrow(ArrowElement element, Canvas canvas) {
    final paint = Paint()
      ..color = element.color
      ..strokeWidth = element.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (element.arrowType) {
      case ArrowType.straight:
        if (element.isDashed) {
          _drawDashedLine(canvas, element.startPoint, element.endPoint, paint);
        } else {
          canvas.drawLine(element.startPoint, element.endPoint, paint);
        }
        _drawArrowHead(element, canvas, element.endPoint, element.startPoint);
        break;
      case ArrowType.curved:
        final cp = element.controlPoint ?? _defaultControlPoint(element);
        final path = Path()
          ..moveTo(element.startPoint.dx, element.startPoint.dy)
          ..quadraticBezierTo(
            cp.dx,
            cp.dy,
            element.endPoint.dx,
            element.endPoint.dy,
          );
        canvas.drawPath(path, paint);
        _drawArrowHead(element, canvas, element.endPoint, cp);
        break;
      case ArrowType.doubleSided:
        if (element.isDashed) {
          _drawDashedLine(canvas, element.startPoint, element.endPoint, paint);
        } else {
          canvas.drawLine(element.startPoint, element.endPoint, paint);
        }
        _drawArrowHead(element, canvas, element.endPoint, element.startPoint);
        _drawArrowHead(element, canvas, element.startPoint, element.endPoint);
        break;
    }
  }

  static void _paintShape(ShapeElement element, Canvas canvas) {
    if (element.fillColor != null) {
      final fillPaint = Paint()
        ..color = element.fillColor!
        ..style = PaintingStyle.fill;
      _drawShape(element, canvas, fillPaint);
    }

    final strokePaint = Paint()
      ..color = element.strokeColor
      ..strokeWidth = element.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (element.isDashed) {
      _drawDashedShape(element, canvas, strokePaint);
    } else {
      _drawShape(element, canvas, strokePaint);
    }
  }

  static void _paintText(TextAnnotation element, Canvas canvas) {
    final tp = buildTextPainter(element);
    tp.layout(maxWidth: element.maxWidth);

    if (element.backgroundColor != null) {
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          element.position.dx - 4,
          element.position.dy - 2,
          tp.width + 16,
          tp.height + 8,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(bgRect, Paint()..color = element.backgroundColor!);
    }

    tp.paint(canvas, Offset(element.position.dx + 4, element.position.dy + 2));
  }

  static TextPainter buildTextPainter(TextAnnotation element) {
    return TextPainter(
      text: TextSpan(
        text: element.text,
        style:
            element.style ??
            TextStyle(
              color: element.textColor,
              fontSize: element.fontSize,
              fontWeight: element.fontWeight,
            ),
      ),
      textDirection: TextDirection.ltr,
    );
  }

  static Offset _defaultControlPoint(ArrowElement element) {
    final midX = (element.startPoint.dx + element.endPoint.dx) / 2;
    final midY = (element.startPoint.dy + element.endPoint.dy) / 2;
    final dx = element.endPoint.dx - element.startPoint.dx;
    final dy = element.endPoint.dy - element.startPoint.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist <= 0) return element.startPoint;
    final offsetAmount = dist * 0.3;
    return Offset(
      midX - dy / dist * offsetAmount,
      midY + dx / dist * offsetAmount,
    );
  }

  static void _drawArrowHead(
    ArrowElement element,
    Canvas canvas,
    Offset tip,
    Offset from,
  ) {
    final dx = tip.dx - from.dx;
    final dy = tip.dy - from.dy;
    if (dx == 0 && dy == 0) return;
    final angle = atan2(dy, dx);
    const arrowLength = 14.0;
    const arrowAngle = 0.5;

    final p1 = Offset(
      tip.dx - arrowLength * cos(angle - arrowAngle),
      tip.dy - arrowLength * sin(angle - arrowAngle),
    );
    final p2 = Offset(
      tip.dx - arrowLength * cos(angle + arrowAngle),
      tip.dy - arrowLength * sin(angle + arrowAngle),
    );

    final fillPaint = Paint()
      ..color = element.color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = element.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, element.strokeWidth)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    switch (element.headStyle) {
      case ArrowHeadStyle.filled:
        canvas.drawPath(path, fillPaint);
        break;
      case ArrowHeadStyle.hollow:
        canvas.drawPath(path, strokePaint);
        break;
      case ArrowHeadStyle.diamond:
        final base = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final tail = Offset(
          tip.dx - arrowLength * 1.35 * cos(angle),
          tip.dy - arrowLength * 1.35 * sin(angle),
        );
        final diamond = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(tail.dx, tail.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.drawPath(diamond, fillPaint);
        canvas.drawLine(base, tail, strokePaint);
        break;
      case ArrowHeadStyle.circle:
        canvas.drawCircle(tip, arrowLength * 0.32, fillPaint);
        break;
    }
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const dashWidth = 8.0;
    const dashSpace = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = sqrt(dx * dx + dy * dy);
    if (length <= 0) return;
    final unitDx = dx / length;
    final unitDy = dy / length;

    double distance = 0;
    while (distance < length) {
      final dashEnd = min(distance + dashWidth, length);
      canvas.drawLine(
        Offset(start.dx + unitDx * distance, start.dy + unitDy * distance),
        Offset(start.dx + unitDx * dashEnd, start.dy + unitDy * dashEnd),
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  static void _drawShape(ShapeElement element, Canvas canvas, Paint paint) {
    switch (element.shapeType) {
      case ShapeType.rectangle:
        if (element.cornerRadius > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              element.rect,
              Radius.circular(element.cornerRadius),
            ),
            paint,
          );
        } else {
          canvas.drawRect(element.rect, paint);
        }
        break;
      case ShapeType.ellipse:
        canvas.drawOval(element.rect, paint);
        break;
      case ShapeType.line:
        canvas.drawLine(element.rect.topLeft, element.rect.bottomRight, paint);
        break;
    }
  }

  static void _drawDashedShape(
    ShapeElement element,
    Canvas canvas,
    Paint paint,
  ) {
    final path = Path();
    switch (element.shapeType) {
      case ShapeType.rectangle:
        if (element.cornerRadius > 0) {
          path.addRRect(
            RRect.fromRectAndRadius(
              element.rect,
              Radius.circular(element.cornerRadius),
            ),
          );
        } else {
          path.addRect(element.rect);
        }
        break;
      case ShapeType.ellipse:
        path.addOval(element.rect);
        break;
      case ShapeType.line:
        path.moveTo(element.rect.topLeft.dx, element.rect.topLeft.dy);
        path.lineTo(element.rect.bottomRight.dx, element.rect.bottomRight.dy);
        break;
    }

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      const dashLen = 8.0;
      const gapLen = 4.0;
      while (distance < metric.length) {
        final end = (distance + dashLen).clamp(0.0, metric.length);
        final extracted = metric.extractPath(distance, end);
        canvas.drawPath(extracted, paint);
        distance += dashLen + gapLen;
      }
    }
  }

  static void _paintFreeDraw(FreeDrawElement element, Canvas canvas) {
    if (element.points.length < 2) return;

    final paint = Paint()
      ..color = element.isHighlighter
          ? element.color.withValues(alpha: 0.4)
          : element.color
      ..strokeWidth = element.isHighlighter
          ? element.strokeWidth * 4
          : element.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (element.isHighlighter) {
      paint.blendMode = BlendMode.multiply;
    }

    final path = Path()
      ..moveTo(element.points.first.dx, element.points.first.dy);
    for (int i = 1; i < element.points.length; i++) {
      if (i < element.points.length - 1) {
        final mid = Offset(
          (element.points[i].dx + element.points[i + 1].dx) / 2,
          (element.points[i].dy + element.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(
          element.points[i].dx,
          element.points[i].dy,
          mid.dx,
          mid.dy,
        );
      } else {
        path.lineTo(element.points[i].dx, element.points[i].dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  static void _paintBlur(BlurElement element, Canvas canvas, Size size) {
    switch (element.blurMode) {
      case BlurMode.mosaic:
        element.paintMosaic(canvas);
        break;
      case BlurMode.gaussianBlur:
        element.paintGaussianBlur(canvas);
        break;
      case BlurMode.spotlight:
        element.paintSpotlight(canvas, size);
        break;
    }
  }

  static void _paintCounter(CounterElement element, Canvas canvas) {
    final bgPaint = Paint()
      ..color = element.color
      ..style = PaintingStyle.fill;
    final rect = Rect.fromCenter(
      center: element.position,
      width: element.size,
      height: element.size,
    );
    switch (element.counterStyle) {
      case CounterStyle.circle:
        canvas.drawCircle(element.position, element.size / 2, bgPaint);
        break;
      case CounterStyle.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(element.size * 0.16)),
          bgPaint,
        );
        break;
      case CounterStyle.diamond:
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
        canvas.drawPath(path, bgPaint);
        break;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${element.number}',
        style: TextStyle(
          color: Colors.white,
          fontSize: element.size * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        element.position.dx - textPainter.width / 2,
        element.position.dy - textPainter.height / 2,
      ),
    );
  }

  static void _paintSticker(
    StickerElement element,
    Canvas canvas,
    StickerRenderCache? stickerCache,
  ) {
    canvas.save();

    final center = element.rect.center;
    final scaleX = element.isFlippedH ? -1.0 : 1.0;
    final scaleY = element.isFlippedV ? -1.0 : 1.0;
    if (element.isFlippedH || element.isFlippedV) {
      canvas.translate(center.dx, center.dy);
      canvas.scale(scaleX, scaleY);
      canvas.translate(-center.dx, -center.dy);
    }

    final renderData = stickerCache?.renderFor(element);
    if (renderData?.pictureInfo != null) {
      element.drawSvgPicture(canvas, renderData!.pictureInfo!);
    } else if (renderData?.image != null) {
      element.drawPngImage(canvas, renderData!.image!);
    } else {
      element.drawFallback(canvas);
    }

    canvas.restore();
  }
}
