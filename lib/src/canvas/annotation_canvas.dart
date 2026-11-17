import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final AnnotationCanvasColorPickCallback? onColorPick;
  final AnnotationCanvasFillCallback? onFill;
  final ValueChanged<TextAnnotation>? onTextEdit;

  const AnnotationCanvas({
    super.key,
    required this.imageBytes,
    required this.imageSize,
    this.controller,
    this.stickerRenderCache,
    this.localizations = const DefaultImageEditorLocalizations(),
    this.onColorPick,
    this.onFill,
    this.onTextEdit,
  });

  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

typedef AnnotationCanvasColorPickCallback = void Function(Offset imagePosition);
typedef AnnotationCanvasFillCallback = void Function(Offset imagePosition);

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  late AnnotationController _controller;
  late StickerRenderCache _stickerRenderCache;
  late bool _ownsController;
  late bool _ownsStickerRenderCache;
  final _currentFreeDrawPoints = <Offset>[];
  Offset? _creationStart;
  Offset? _creationEnd;
  final _focusNode = FocusNode();

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
    _focusNode.dispose();
    _disposeOwnedStickerRenderCache();
    _disposeOwnedController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
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
                    _focusNode.requestFocus();
                    _handleTap(
                      _toImagePosition(
                        details.localPosition,
                        canvasSize,
                        currentImageSize,
                      ),
                    );
                  },
                  onDoubleTapDown: (details) {
                    _handleDoubleTap(
                      _toImagePosition(
                        details.localPosition,
                        canvasSize,
                        currentImageSize,
                      ),
                    );
                  },
                  onDoubleTap: () {},
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
                              activeElement: _buildActivePreview(),
                              selectedElementIds: _controller.selectedElementIds
                                  .toSet(),
                              alignmentGuides: _controller.alignmentGuides
                                  .toList(),
                              stickerRenderCache: _stickerRenderCache,
                              localizations: widget.localizations,
                              selectionColor: Theme.of(
                                context,
                              ).colorScheme.primary,
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
        },
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelCreation();
      _controller.clearSelection();
      _controller.setTool(AnnotateTool.select);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      _controller.deleteSelected();
      return KeyEventResult.handled;
    }
    const nudgeStep = 1.0;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _controller.nudgeSelected(const Offset(-nudgeStep, 0));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _controller.nudgeSelected(const Offset(nudgeStep, 0));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _controller.nudgeSelected(const Offset(0, -nudgeStep));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _controller.nudgeSelected(const Offset(0, nudgeStep));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleTap(Offset position) {
    if (_currentFreeDrawPoints.isNotEmpty) return;
    final tool = _controller.currentTool.value;
    switch (tool) {
      case AnnotateTool.eraser:
        _controller.eraseAt(position);
      case AnnotateTool.text:
        _commitTextElement(position);
      case AnnotateTool.counter:
        _commitCounterElement(position);
      case AnnotateTool.colorPicker:
        widget.onColorPick?.call(position);
      case AnnotateTool.fill:
        widget.onFill?.call(position);
      case AnnotateTool.select:
        _selectTopmostAt(position);
      default:
        _selectTopmostAt(position);
    }
  }

  void _handleDoubleTap(Offset position) {
    for (final element in _controller.elements.reversed) {
      if (element is TextAnnotation && element.hitTest(position)) {
        widget.onTextEdit?.call(element);
        return;
      }
    }
  }

  void _handlePanStart(Offset position) {
    final tool = _controller.currentTool.value;
    switch (tool) {
      case AnnotateTool.pencil:
      case AnnotateTool.highlighter:
        _currentFreeDrawPoints
          ..clear()
          ..add(position);
      case AnnotateTool.eraser:
        _currentFreeDrawPoints
          ..clear()
          ..add(position);
      case AnnotateTool.arrow:
      case AnnotateTool.rectangle:
      case AnnotateTool.ellipse:
      case AnnotateTool.line:
      case AnnotateTool.blur:
      case AnnotateTool.solidRedaction:
      case AnnotateTool.spotlight:
        _creationStart = position;
        _creationEnd = position;
      case AnnotateTool.select:
        _handleSelectPanStart(position);
      default:
        break;
    }
  }

  void _handlePanUpdate(Offset position) {
    final tool = _controller.currentTool.value;
    switch (tool) {
      case AnnotateTool.pencil:
      case AnnotateTool.highlighter:
        if (_currentFreeDrawPoints.isEmpty) return;
        if (_currentFreeDrawPoints.length <
            AnnotationController.maxFreeDrawPoints) {
          _currentFreeDrawPoints.add(position);
        } else {
          _currentFreeDrawPoints[_currentFreeDrawPoints.length - 1] = position;
        }
      case AnnotateTool.eraser:
        if (_currentFreeDrawPoints.isNotEmpty) {
          _currentFreeDrawPoints.add(position);
        }
      case AnnotateTool.arrow:
      case AnnotateTool.rectangle:
      case AnnotateTool.ellipse:
      case AnnotateTool.line:
      case AnnotateTool.blur:
      case AnnotateTool.solidRedaction:
      case AnnotateTool.spotlight:
        _creationEnd = position;
      case AnnotateTool.select:
        _handleSelectPanUpdate(position);
      default:
        break;
    }
    setState(() {});
  }

  void _handlePanEnd() {
    final tool = _controller.currentTool.value;
    switch (tool) {
      case AnnotateTool.pencil:
      case AnnotateTool.highlighter:
        _commitFreeDraw();
      case AnnotateTool.eraser:
        if (_currentFreeDrawPoints.length >= 2) {
          _controller.eraseAlongPath(_currentFreeDrawPoints);
        }
        _currentFreeDrawPoints.clear();
      case AnnotateTool.arrow:
        _commitArrowElement();
      case AnnotateTool.rectangle:
        _commitShapeElement(ShapeType.rectangle);
      case AnnotateTool.ellipse:
        _commitShapeElement(ShapeType.ellipse);
      case AnnotateTool.line:
        _commitLineElement();
      case AnnotateTool.blur:
        _commitBlurElement(BlurMode.mosaic);
      case AnnotateTool.spotlight:
        _commitBlurElement(BlurMode.spotlight);
      case AnnotateTool.solidRedaction:
        _commitSolidRedactionElement();
      case AnnotateTool.select:
        _handleSelectPanEnd();
      default:
        break;
    }
    _creationStart = null;
    _creationEnd = null;
    setState(() {});
  }

  void _commitFreeDraw() {
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

  void _commitArrowElement() {
    final start = _creationStart;
    final end = _creationEnd;
    if (start == null || end == null) return;
    if ((start - end).distance < 3) return;
    _controller.addElement(
      ArrowElement(
        startPoint: start,
        endPoint: end,
        color: _controller.currentColor.value,
        strokeWidth: _controller.currentStrokeWidth.value,
      ),
    );
  }

  void _commitShapeElement(ShapeType type) {
    final start = _creationStart;
    final end = _creationEnd;
    if (start == null || end == null) return;
    final rect = Rect.fromPoints(start, end);
    if (rect.width < 3 || rect.height < 3) return;
    _controller.addElement(
      ShapeElement(
        rect: rect,
        strokeColor: _controller.currentColor.value,
        fillColor: _controller.useFillColor.value
            ? _controller.currentFillColor.value
            : null,
        strokeWidth: _controller.currentStrokeWidth.value,
        shapeType: type,
      ),
    );
  }

  void _commitLineElement() {
    final start = _creationStart;
    final end = _creationEnd;
    if (start == null || end == null) return;
    if ((start - end).distance < 3) return;
    _controller.addElement(
      ShapeElement(
        rect: Rect.fromPoints(start, end),
        strokeColor: _controller.currentColor.value,
        strokeWidth: _controller.currentStrokeWidth.value,
        shapeType: ShapeType.line,
      ),
    );
  }

  void _commitBlurElement(BlurMode mode) {
    final start = _creationStart;
    final end = _creationEnd;
    if (start == null || end == null) return;
    final rect = Rect.fromPoints(start, end);
    if (rect.width < 5 || rect.height < 5) return;
    _controller.addElement(
      BlurElement(rect: rect, blurMode: mode, intensity: 10),
    );
  }

  void _commitSolidRedactionElement() {
    final start = _creationStart;
    final end = _creationEnd;
    if (start == null || end == null) return;
    final rect = Rect.fromPoints(start, end);
    if (rect.width < 3 || rect.height < 3) return;
    _controller.addElement(
      ShapeElement(
        rect: rect,
        strokeColor: _controller.currentColor.value,
        fillColor: _controller.currentColor.value,
        strokeWidth: 0,
        shapeType: ShapeType.rectangle,
      ),
    );
  }

  void _commitTextElement(Offset position) {
    _controller.addElement(
      TextAnnotation(
        text: '',
        position: position,
        textColor: _controller.currentColor.value,
        fontSize: _controller.currentFontSize.value,
      ),
    );
    final added = _controller.elements.last;
    _controller.selectElement(added.id);
    widget.onTextEdit?.call(added as TextAnnotation);
  }

  void _commitCounterElement(Offset position) {
    _controller.addElement(
      CounterElement(
        number: _controller.nextCounter.value,
        position: position,
        color: _controller.currentColor.value,
      ),
    );
  }

  AnnotationElement? _buildActivePreview() {
    final start = _creationStart;
    final end = _creationEnd;
    if (start == null || end == null) return null;
    final tool = _controller.currentTool.value;
    switch (tool) {
      case AnnotateTool.arrow:
        return ArrowElement(
          startPoint: start,
          endPoint: end,
          color: _controller.currentColor.value.withValues(alpha: 0.6),
          strokeWidth: _controller.currentStrokeWidth.value,
        );
      case AnnotateTool.rectangle:
        return ShapeElement(
          rect: Rect.fromPoints(start, end),
          strokeColor: _controller.currentColor.value.withValues(alpha: 0.6),
          fillColor: _controller.useFillColor.value
              ? _controller.currentFillColor.value.withValues(alpha: 0.3)
              : null,
          strokeWidth: _controller.currentStrokeWidth.value,
          shapeType: ShapeType.rectangle,
        );
      case AnnotateTool.ellipse:
        return ShapeElement(
          rect: Rect.fromPoints(start, end),
          strokeColor: _controller.currentColor.value.withValues(alpha: 0.6),
          fillColor: _controller.useFillColor.value
              ? _controller.currentFillColor.value.withValues(alpha: 0.3)
              : null,
          strokeWidth: _controller.currentStrokeWidth.value,
          shapeType: ShapeType.ellipse,
        );
      case AnnotateTool.line:
        return ShapeElement(
          rect: Rect.fromPoints(start, end),
          strokeColor: _controller.currentColor.value.withValues(alpha: 0.6),
          strokeWidth: _controller.currentStrokeWidth.value,
          shapeType: ShapeType.line,
        );
      case AnnotateTool.blur:
      case AnnotateTool.spotlight:
      case AnnotateTool.solidRedaction:
        return ShapeElement(
          rect: Rect.fromPoints(start, end),
          strokeColor: const Color(0x80808080),
          strokeWidth: 1,
          shapeType: ShapeType.rectangle,
          isDashed: true,
        );
      default:
        return null;
    }
  }

  void _cancelCreation() {
    _creationStart = null;
    _creationEnd = null;
    _currentFreeDrawPoints.clear();
    setState(() {});
  }

  Offset? _selectDragStart;

  void _handleSelectPanStart(Offset position) {
    final hit = _selectTopmostAt(position);
    if (hit) {
      _selectDragStart = position;
      _controller.beginElementTransform();
    }
  }

  void _handleSelectPanUpdate(Offset position) {
    final start = _selectDragStart;
    if (start == null) return;
    final delta = position - start;
    _selectDragStart = position;
    _controller.nudgeSelected(delta);
    final selected = _controller.selectedElements;
    if (selected.length == 1) {
      _controller.updateAlignmentGuides(selected.first);
    }
  }

  void _handleSelectPanEnd() {
    _selectDragStart = null;
    _controller.finishElementTransform();
  }

  bool _selectTopmostAt(Offset position) {
    for (final element in _controller.elements.reversed) {
      if (element.hitTest(position)) {
        _controller.selectElement(element.id);
        return true;
      }
    }
    _controller.selectElement(null);
    return false;
  }

  void _disposeOwnedController() {
    if (_ownsController) {
      _controller.dispose();
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
