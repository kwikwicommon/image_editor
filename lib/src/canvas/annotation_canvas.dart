import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/image_editor_localizations.dart';
import '../stickers/sticker_render_cache.dart';
import '../tools/tool_types.dart';
import 'alignment_guide.dart';
import 'annotation_controller.dart';
import 'annotation_element.dart';
import 'annotation_painter.dart';

class AnnotationCanvas extends StatefulWidget {
  final Uint8List imageBytes;
  final Size imageSize;
  final AnnotationController? controller;
  final StickerRenderCache? stickerRenderCache;
  final ImageEditorLocalizations localizations;

  const AnnotationCanvas({
    super.key,
    required this.imageBytes,
    required this.imageSize,
    this.controller,
    this.stickerRenderCache,
    this.localizations = const DefaultImageEditorLocalizations(),
  });

  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  late AnnotationController _controller;
  late StickerRenderCache _stickerRenderCache;
  late bool _ownsController;
  late bool _ownsStickerRenderCache;
  final _currentFreeDrawPoints = <Offset>[];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _ownsStickerRenderCache = widget.stickerRenderCache == null;
    _controller = widget.controller ?? AnnotationController();
    _stickerRenderCache = widget.stickerRenderCache ?? StickerRenderCache();
    if (_ownsController || _controller.backgroundImage.value == null) {
      _controller.loadImage(widget.imageBytes, widget.imageSize);
    }
  }

  @override
  void didUpdateWidget(covariant AnnotationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _disposeOwnedController();
      _ownsController = widget.controller == null;
      _controller = widget.controller ?? AnnotationController();
      if (_ownsController || _controller.backgroundImage.value == null) {
        _controller.loadImage(widget.imageBytes, widget.imageSize);
      }
    }
    if (oldWidget.stickerRenderCache != widget.stickerRenderCache) {
      _disposeOwnedStickerRenderCache();
      _ownsStickerRenderCache = widget.stickerRenderCache == null;
      _stickerRenderCache = widget.stickerRenderCache ?? StickerRenderCache();
    }
    if (_ownsController &&
        (oldWidget.imageBytes != widget.imageBytes ||
            oldWidget.imageSize != widget.imageSize)) {
      _controller.loadImage(widget.imageBytes, widget.imageSize);
    }
  }

  @override
  void dispose() {
    _disposeOwnedStickerRenderCache();
    _disposeOwnedController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentImageBytes =
          _controller.backgroundImage.value ?? widget.imageBytes;
      final currentImageSize = _safeImageSize(
        _controller.imageSize.value ?? widget.imageSize,
      );
      return AspectRatio(
        aspectRatio: currentImageSize.width / currentImageSize.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _handleTap(
                  _toImagePosition(
                    details.localPosition,
                    canvasSize,
                    currentImageSize,
                  ),
                );
              },
              onPanStart: (details) {
                _handlePanStart(
                  _toImagePosition(
                    details.localPosition,
                    canvasSize,
                    currentImageSize,
                  ),
                );
              },
              onPanUpdate: (details) {
                _handlePanUpdate(
                  _toImagePosition(
                    details.localPosition,
                    canvasSize,
                    currentImageSize,
                  ),
                );
              },
              onPanEnd: (_) => _handlePanEnd(),
              child: RepaintBoundary(
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(currentImageBytes, fit: BoxFit.fill),
                      CustomPaint(
                        painter: AnnotationCanvasPainter(
                          elements: _controller.elements.toList(),
                          selectedElementIds: _controller.selectedElementIds
                              .toSet(),
                          alignmentGuides: _controller.alignmentGuides.toList(),
                          stickerRenderCache: _stickerRenderCache,
                          localizations: widget.localizations,
                          selectionColor: Theme.of(context).colorScheme.primary,
                          coordinateSize: currentImageSize,
                        ),
                        size: canvasSize,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  void _handleTap(Offset position) {
    if (_currentFreeDrawPoints.isNotEmpty) return;
    switch (_controller.currentTool.value) {
      case AnnotateTool.eraser:
        _controller.eraseAt(position);
        break;
      default:
        _selectTopmostAt(position);
        break;
    }
  }

  void _handlePanStart(Offset position) {
    if (_controller.currentTool.value != AnnotateTool.pencil &&
        _controller.currentTool.value != AnnotateTool.highlighter) {
      return;
    }
    _currentFreeDrawPoints
      ..clear()
      ..add(position);
  }

  void _handlePanUpdate(Offset position) {
    if (_currentFreeDrawPoints.isEmpty) return;
    if (_currentFreeDrawPoints.length <
        AnnotationController.maxFreeDrawPoints) {
      _currentFreeDrawPoints.add(position);
    } else {
      _currentFreeDrawPoints[_currentFreeDrawPoints.length - 1] = position;
    }
  }

  void _handlePanEnd() {
    if (_currentFreeDrawPoints.length < 2) {
      _currentFreeDrawPoints.clear();
      return;
    }
    _controller.addElement(
      FreeDrawElement(
        points: List.unmodifiable(_currentFreeDrawPoints),
        color: _controller.currentColor.value.withValues(
          alpha: _controller.currentOpacity.value,
        ),
        strokeWidth: _controller.currentStrokeWidth.value,
        isHighlighter:
            _controller.currentTool.value == AnnotateTool.highlighter,
      ),
    );
    _currentFreeDrawPoints.clear();
  }

  void _selectTopmostAt(Offset position) {
    for (final element in _controller.elements.reversed) {
      if (element.hitTest(position)) {
        _controller.selectElement(element.id);
        return;
      }
    }
    _controller.selectElement(null);
  }

  void _disposeOwnedController() {
    if (_ownsController && !_controller.isClosed) {
      _controller.onDelete();
    }
  }

  void _disposeOwnedStickerRenderCache() {
    if (!_ownsStickerRenderCache) return;
    _stickerRenderCache.dispose();
  }

  Offset _toImagePosition(
    Offset localPosition,
    Size canvasSize,
    Size imageSize,
  ) {
    if (canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return localPosition;
    }
    return Offset(
      localPosition.dx * imageSize.width / canvasSize.width,
      localPosition.dy * imageSize.height / canvasSize.height,
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

class AnnotationCanvasPainter extends CustomPainter {
  final List<AnnotationElement> elements;
  final AnnotationElement? activeElement;
  final Color selectionColor;
  final double selectionStrokeWidth;
  final double handleSize;
  final double handleRadius;
  final Color labelTextColor;
  final Color labelBackgroundColor;
  final double labelFontSize;
  final double labelRadius;
  final EdgeInsets labelPadding;
  final bool showSelectionHandles;
  final Set<String> selectedElementIds;
  final List<AlignmentGuide> alignmentGuides;
  final Rect? dragFeedbackBounds;
  final bool showActiveBoundsLabel;
  final Rect? insertFeedbackBounds;
  final double insertFeedbackProgress;
  final StickerRenderCache stickerRenderCache;
  final ImageEditorLocalizations localizations;
  final Size? coordinateSize;

  AnnotationCanvasPainter({
    required this.elements,
    required this.selectionColor,
    required this.stickerRenderCache,
    required this.localizations,
    this.activeElement,
    this.selectionStrokeWidth = 1.5,
    this.handleSize = 8,
    this.handleRadius = 3,
    this.labelTextColor = Colors.white,
    this.labelBackgroundColor = const Color(0xCC111827),
    this.labelFontSize = 11,
    this.labelRadius = 4,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    this.showSelectionHandles = true,
    this.selectedElementIds = const {},
    this.alignmentGuides = const [],
    this.dragFeedbackBounds,
    this.showActiveBoundsLabel = true,
    this.insertFeedbackBounds,
    this.insertFeedbackProgress = 1.0,
    this.coordinateSize,
  }) : super(repaint: stickerRenderCache);

  @override
  void paint(Canvas canvas, Size size) {
    final contentSize = _resolvedCoordinateSize(size);
    final scale = _contentScale(size, contentSize);

    canvas.save();
    canvas.scale(scale.dx, scale.dy);
    for (final element in elements) {
      AnnotationElementPainter.paint(
        element,
        canvas,
        contentSize,
        stickerCache: stickerRenderCache,
      );
    }

    if (activeElement != null) {
      AnnotationElementPainter.paint(
        activeElement!,
        canvas,
        contentSize,
        stickerCache: stickerRenderCache,
      );
    }
    canvas.restore();

    if (activeElement != null && showActiveBoundsLabel) {
      _drawBoundsLabel(
        canvas,
        _scaleRect(activeElement!.bounds, scale),
        activeElement!.bounds,
        size,
      );
    }

    _drawAlignmentGuides(canvas, size, scale);

    if (dragFeedbackBounds != null) {
      _drawBoundsLabel(
        canvas,
        _scaleRect(dragFeedbackBounds!, scale),
        dragFeedbackBounds!,
        size,
      );
    }

    if (insertFeedbackBounds != null) {
      _drawInsertFeedback(canvas, _scaleRect(insertFeedbackBounds!, scale));
    }

    if (showSelectionHandles) {
      for (final element in elements) {
        if (element.isVisible && selectedElementIds.contains(element.id)) {
          _drawSelectionHandles(canvas, element, scale);
        }
      }
    }
  }

  void _drawSelectionHandles(
    Canvas canvas,
    AnnotationElement element,
    Offset scale,
  ) {
    final bounds = _scaleRect(element.bounds, scale);
    final borderPaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = selectionStrokeWidth;
    canvas.drawRect(bounds.inflate(4), borderPaint);

    final handlePaint = Paint()
      ..color = selectionColor
      ..style = PaintingStyle.fill;
    final handleCenters = [
      bounds.topLeft,
      bounds.topCenter,
      bounds.topRight,
      bounds.centerLeft,
      bounds.centerRight,
      bounds.bottomLeft,
      bounds.bottomCenter,
      bounds.bottomRight,
    ];
    for (final center in handleCenters) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: handleSize,
            height: handleSize,
          ),
          Radius.circular(handleRadius),
        ),
        handlePaint,
      );
    }
  }

  void _drawAlignmentGuides(Canvas canvas, Size size, Offset scale) {
    if (alignmentGuides.isEmpty) return;
    final guidePaint = Paint()
      ..color = selectionColor.withValues(alpha: 0.72)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final guide in alignmentGuides) {
      if (guide.isHorizontal) {
        final position = guide.position * scale.dy;
        canvas.drawLine(
          Offset(0, position),
          Offset(size.width, position),
          guidePaint,
        );
      } else {
        final position = guide.position * scale.dx;
        canvas.drawLine(
          Offset(position, 0),
          Offset(position, size.height),
          guidePaint,
        );
      }
    }
  }

  void _drawBoundsLabel(
    Canvas canvas,
    Rect displayBounds,
    Rect sourceBounds,
    Size size,
  ) {
    if (displayBounds.isEmpty || sourceBounds.isEmpty) return;
    final text = localizations.dimensions(
      sourceBounds.width,
      sourceBounds.height,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: labelTextColor,
          fontSize: labelFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final labelWidth = textPainter.width + labelPadding.horizontal;
    final labelHeight = textPainter.height + labelPadding.vertical;
    final margin = handleRadius + selectionStrokeWidth;
    final maxLeft = size.width - labelWidth - margin;
    final left = maxLeft <= margin
        ? margin
        : (displayBounds.center.dx - labelWidth / 2)
              .clamp(margin, maxLeft)
              .toDouble();
    final preferredTop =
        displayBounds.bottom + margin + labelHeight <= size.height
        ? displayBounds.bottom + margin
        : displayBounds.top - labelHeight - margin;
    final maxTop = size.height - labelHeight - margin;
    final top = maxTop <= margin
        ? margin
        : preferredTop.clamp(margin, maxTop).toDouble();
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, labelWidth, labelHeight),
      Radius.circular(labelRadius),
    );
    canvas.drawRRect(labelRect, Paint()..color = labelBackgroundColor);
    textPainter.paint(
      canvas,
      Offset(left + labelPadding.left, top + labelPadding.top),
    );
  }

  void _drawInsertFeedback(Canvas canvas, Rect bounds) {
    final progress = insertFeedbackProgress.clamp(0.0, 1.0).toDouble();
    final expand = 6 + progress * 12;
    final alpha = (1 - progress) * 0.42;
    if (alpha <= 0) return;

    final paint = Paint()
      ..color = selectionColor.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.inflate(expand), const Radius.circular(8)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant AnnotationCanvasPainter oldDelegate) {
    return elements != oldDelegate.elements ||
        activeElement != oldDelegate.activeElement ||
        selectionColor != oldDelegate.selectionColor ||
        selectionStrokeWidth != oldDelegate.selectionStrokeWidth ||
        handleSize != oldDelegate.handleSize ||
        handleRadius != oldDelegate.handleRadius ||
        showSelectionHandles != oldDelegate.showSelectionHandles ||
        selectedElementIds != oldDelegate.selectedElementIds ||
        alignmentGuides != oldDelegate.alignmentGuides ||
        dragFeedbackBounds != oldDelegate.dragFeedbackBounds ||
        showActiveBoundsLabel != oldDelegate.showActiveBoundsLabel ||
        insertFeedbackBounds != oldDelegate.insertFeedbackBounds ||
        insertFeedbackProgress != oldDelegate.insertFeedbackProgress ||
        labelTextColor != oldDelegate.labelTextColor ||
        labelBackgroundColor != oldDelegate.labelBackgroundColor ||
        labelFontSize != oldDelegate.labelFontSize ||
        labelRadius != oldDelegate.labelRadius ||
        labelPadding != oldDelegate.labelPadding ||
        localizations != oldDelegate.localizations ||
        coordinateSize != oldDelegate.coordinateSize;
  }

  Size _resolvedCoordinateSize(Size paintSize) {
    final candidate = coordinateSize;
    if (candidate == null ||
        candidate.width <= 0 ||
        candidate.height <= 0 ||
        !candidate.width.isFinite ||
        !candidate.height.isFinite) {
      return paintSize;
    }
    return candidate;
  }

  Offset _contentScale(Size paintSize, Size contentSize) {
    if (contentSize.width <= 0 || contentSize.height <= 0) {
      return const Offset(1, 1);
    }
    return Offset(
      paintSize.width / contentSize.width,
      paintSize.height / contentSize.height,
    );
  }

  Rect _scaleRect(Rect rect, Offset scale) {
    return Rect.fromLTRB(
      rect.left * scale.dx,
      rect.top * scale.dy,
      rect.right * scale.dx,
      rect.bottom * scale.dy,
    );
  }
}
