import 'package:flutter/material.dart';

enum CropAspectRatio {
  free(null),
  square(1),
  r16x9(16 / 9),
  r9x16(9 / 16),
  r4x3(4 / 3),
  r3x4(3 / 4),
  r3x2(3 / 2),
  r2x3(2 / 3),
  r21x9(21 / 9);

  final double? ratio;

  const CropAspectRatio(this.ratio);
}

class CropTool extends StatefulWidget {
  final Size imageSize;
  final CropAspectRatio aspectRatio;
  final ValueChanged<Rect>? onChanged;
  final ValueChanged<Rect>? onSubmitted;
  final VoidCallback? onCancelled;
  final double minWidth;
  final double minHeight;

  const CropTool({
    super.key,
    required this.imageSize,
    this.aspectRatio = CropAspectRatio.free,
    this.onChanged,
    this.onSubmitted,
    this.onCancelled,
    this.minWidth = 10,
    this.minHeight = 10,
  });

  @override
  State<CropTool> createState() => _CropToolState();
}

class _CropToolState extends State<CropTool> {
  Rect? _selection;
  Offset? _dragStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imageSize = _safeImageSize(widget.imageSize);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final start = _clampOffset(
              _toImagePosition(details.localPosition, viewSize, imageSize),
            );
            _dragStart = start;
            _selection = Rect.fromPoints(start, start);
            widget.onChanged?.call(_selection!);
            setState(() {});
          },
          onPanUpdate: (details) {
            final start = _dragStart;
            if (start == null) return;
            _selection = _constrainRect(
              start,
              _toImagePosition(details.localPosition, viewSize, imageSize),
              widget.aspectRatio.ratio,
            );
            widget.onChanged?.call(_selection!);
            setState(() {});
          },
          onPanEnd: (_) {
            final selection = _selection;
            if (selection != null &&
                selection.width >= widget.minWidth &&
                selection.height >= widget.minHeight) {
              widget.onSubmitted?.call(selection);
            } else {
              widget.onCancelled?.call();
            }
            _dragStart = null;
          },
          child: CustomPaint(
            painter: _CropOverlayPainter(
              selection: _selection,
              coordinateSize: imageSize,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  Rect _constrainRect(Offset start, Offset current, double? ratio) {
    final imageSize = _safeImageSize(widget.imageSize);
    final clampedStart = _clampOffset(start);
    final clampedCurrent = _clampOffset(current);
    if (ratio == null || ratio <= 0) {
      return Rect.fromPoints(clampedStart, clampedCurrent);
    }

    final directionX = clampedCurrent.dx >= clampedStart.dx ? 1.0 : -1.0;
    final directionY = clampedCurrent.dy >= clampedStart.dy ? 1.0 : -1.0;
    final maxWidth = directionX > 0
        ? imageSize.width - clampedStart.dx
        : clampedStart.dx;
    final maxHeight = directionY > 0
        ? imageSize.height - clampedStart.dy
        : clampedStart.dy;
    var width = (clampedCurrent.dx - clampedStart.dx)
        .abs()
        .clamp(0.0, maxWidth)
        .toDouble();
    var height = (clampedCurrent.dy - clampedStart.dy)
        .abs()
        .clamp(0.0, maxHeight)
        .toDouble();

    if (width == 0 && height == 0) {
      return Rect.fromPoints(clampedStart, clampedStart);
    }
    if (width == 0) {
      width = (height * ratio).clamp(0.0, maxWidth).toDouble();
      height = width / ratio;
    } else if (height == 0) {
      height = (width / ratio).clamp(0.0, maxHeight).toDouble();
      width = height * ratio;
    } else if (width / height > ratio) {
      width = (height * ratio).clamp(0.0, maxWidth).toDouble();
      height = width / ratio;
    } else {
      height = (width / ratio).clamp(0.0, maxHeight).toDouble();
      width = height * ratio;
    }

    if (width > maxWidth) {
      width = maxWidth;
      height = width / ratio;
    }
    if (height > maxHeight) {
      height = maxHeight;
      width = height * ratio;
    }

    final end = Offset(
      clampedStart.dx + directionX * width,
      clampedStart.dy + directionY * height,
    );
    return Rect.fromPoints(clampedStart, end);
  }

  Offset _clampOffset(Offset offset) {
    final imageSize = _safeImageSize(widget.imageSize);
    return Offset(
      offset.dx.clamp(0.0, imageSize.width).toDouble(),
      offset.dy.clamp(0.0, imageSize.height).toDouble(),
    );
  }

  Offset _toImagePosition(Offset localPosition, Size viewSize, Size imageSize) {
    if (viewSize.width <= 0 || viewSize.height <= 0) {
      return localPosition;
    }
    return Offset(
      localPosition.dx * imageSize.width / viewSize.width,
      localPosition.dy * imageSize.height / viewSize.height,
    );
  }

  Size _safeImageSize(Size size) {
    if (size.width > 0 &&
        size.height > 0 &&
        size.width.isFinite &&
        size.height.isFinite) {
      return size;
    }
    return const Size(1, 1);
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect? selection;
  final Size coordinateSize;

  const _CropOverlayPainter({
    required this.selection,
    required this.coordinateSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = selection;
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final fullRect = Offset.zero & size;
    if (rect == null || rect.isEmpty) {
      canvas.drawRect(fullRect, overlayPaint);
      return;
    }
    final displayRect = _scaleRect(rect, size);

    final path = Path()
      ..addRect(fullRect)
      ..addRect(displayRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(displayRect, borderPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var index = 1; index < 3; index += 1) {
      final dx = displayRect.left + displayRect.width * index / 3;
      final dy = displayRect.top + displayRect.height * index / 3;
      canvas.drawLine(
        Offset(dx, displayRect.top),
        Offset(dx, displayRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(displayRect.left, dy),
        Offset(displayRect.right, dy),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return selection != oldDelegate.selection ||
        coordinateSize != oldDelegate.coordinateSize;
  }

  Rect _scaleRect(Rect rect, Size size) {
    return Rect.fromLTRB(
      rect.left * size.width / coordinateSize.width,
      rect.top * size.height / coordinateSize.height,
      rect.right * size.width / coordinateSize.width,
      rect.bottom * size.height / coordinateSize.height,
    );
  }
}
