import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../tools/tool_types.dart';
import 'alignment_guide.dart';
import 'annotation_element.dart';
import 'annotation_json.dart';

enum AlignmentMode { left, right, top, bottom, centerH, centerV }

class AnnotationController extends ChangeNotifier {
  @override
  void dispose() {
    for (final value in _values) {
      value.dispose();
    }
    super.dispose();
  }

  AnnotationController() {
    for (final value in _values) {
      value.addListener(notifyListeners);
    }
  }

  late final List<ChangeNotifier> _values = [
    backgroundImage,
    imageSize,
    currentTool,
    currentColor,
    currentFillColor,
    useFillColor,
    currentOpacity,
    currentStrokeWidth,
    currentFontSize,
    selectedElementId,
    nextCounter,
  ];

  static const int maxUndoStackDepth = 50;
  static const int maxFreeDrawPoints = 12000;
  static const int _maxInlineStickerImageBytes = 24 * 1024 * 1024;
  static const int _maxInlineStickerSvgBytes = 4 * 1024 * 1024;

  final _historyResourcePool = _AnnotationHistoryResourcePool();

  final backgroundImage = ValueNotifier<Uint8List?>(null);
  final imageSize = ValueNotifier<Size?>(null);
  final elements = <AnnotationElement>[];
  final currentTool = ValueNotifier(AnnotateTool.arrow);
  final currentColor = ValueNotifier(const Color(0xFFE11D48));
  final currentFillColor = ValueNotifier(const Color(0xFFE11D48));
  final useFillColor = ValueNotifier(false);
  final currentOpacity = ValueNotifier(1.0);
  final currentStrokeWidth = ValueNotifier(2.0);
  final currentFontSize = ValueNotifier(16.0);
  final selectedElementId = ValueNotifier<String?>(null);
  final selectedElementIds = <String>{};
  final alignmentGuides = <AlignmentGuide>[];
  final nextCounter = ValueNotifier(1);

  final List<_AnnotationHistoryEntry> _undoStack = [];
  final List<_AnnotationHistoryEntry> _redoStack = [];
  final List<AnnotationElement> _clipboard = [];

  List<List<AnnotationElement>> get undoStack {
    return List.unmodifiable(
      _undoStack.map((entry) => List.unmodifiable(entry.elements)),
    );
  }

  List<List<AnnotationElement>> get redoStack {
    return List.unmodifiable(
      _redoStack.map((entry) => List.unmodifiable(entry.elements)),
    );
  }

  List<AnnotationElement> get clipboard => List.unmodifiable(_clipboard);
  bool get hasMultiSelection => selectedElementIds.length > 1;

  List<AnnotationElement> get selectedElements {
    return elements.where((element) {
      return selectedElementIds.contains(element.id);
    }).toList();
  }

  void loadImage(Uint8List imageBytes, Size size) {
    backgroundImage.value = imageBytes;
    imageSize.value = size;
    elements.clear();
    notifyListeners();
    _undoStack.clear();
    _redoStack.clear();
    _clipboard.clear();
    _historyResourcePool.clear();
    nextCounter.value = 1;
    clearSelection();
  }

  void loadProject({
    required Uint8List imageBytes,
    required Size imageSize,
    required List<AnnotationElement> elements,
  }) {
    final loadedElements = _reindexElements(
      elements.map(_prepareElementForState).toList(),
    );
    backgroundImage.value = imageBytes;
    this.imageSize.value = imageSize;
    this.elements
      ..clear()
      ..addAll(loadedElements);
    notifyListeners();
    _undoStack.clear();
    _redoStack.clear();
    _clipboard.clear();
    _historyResourcePool.clear();
    nextCounter.value = _nextCounterFor(loadedElements);
    clearSelection();
  }

  void setTool(AnnotateTool tool) {
    currentTool.value = tool;
    clearSelection();
  }

  void setColor(Color color) {
    currentColor.value = color;
  }

  void setFillColor(Color color) {
    currentFillColor.value = color;
    useFillColor.value = true;
  }

  void setUseFillColor(bool enabled) {
    useFillColor.value = enabled;
  }

  void setOpacity(double opacity) {
    if (!opacity.isFinite) return;
    currentOpacity.value = opacity.clamp(0.15, 1.0).toDouble();
  }

  void setStrokeWidth(double width) {
    if (!width.isFinite) return;
    currentStrokeWidth.value = width.clamp(1.0, 64.0).toDouble();
  }

  void setFontSize(double size) {
    if (!size.isFinite) return;
    currentFontSize.value = size.clamp(6.0, 256.0).toDouble();
  }

  void addElement(AnnotationElement element) {
    final storedElement = _prepareElementForState(
      element.translated(Offset.zero, zIndex: elements.length),
    );
    _saveUndoState();
    elements.add(storedElement);
    notifyListeners();
    _advanceNextCounterFor([storedElement]);
    _clearRedoStack();
  }

  void updateElement(String id, AnnotationElement updated) {
    final existing = _elementById(id);
    if (existing == null || existing.isLocked) return;
    final prepared = _prepareElementForState(updated);
    _saveUndoState();
    _replaceElement(id, prepared);
    _advanceNextCounterFor([prepared]);
    _clearRedoStack();
  }

  void updateElementContinuously(String id, AnnotationElement updated) {
    final existing = _elementById(id);
    if (existing == null || existing.isLocked) return;
    _replaceElement(id, updated);
  }

  void beginElementTransform() {
    if (!_hasTransformableSelection()) return;
    _saveUndoState();
    _clearRedoStack();
  }

  void finishElementTransform() {
    clearAlignmentGuides();
  }

  void selectElement(String? id) {
    final selectable = id == null ? null : _elementById(id);
    final selectedId = selectable == null || !selectable.isVisible ? null : id;
    selectedElementId.value = selectedId;
    selectedElementIds
      ..clear()
      ..addAll(selectedId == null ? const <String>[] : [selectedId]);
    notifyListeners();
  }

  void toggleSelectElement(String id) {
    final selectable = _elementById(id);
    if (selectable == null || !selectable.isVisible) return;
    if (selectedElementIds.contains(id)) {
      selectedElementIds.remove(id);
      notifyListeners();
    } else {
      selectedElementIds.add(id);
      notifyListeners();
    }
    selectedElementId.value = selectedElementIds.isEmpty
        ? null
        : selectedElementIds.last;
  }

  void selectElementsInRect(Rect selectionRect) {
    final ids = <String>{};
    for (final element in elements) {
      if (element.isVisible && element.bounds.overlaps(selectionRect)) {
        ids.add(element.id);
      }
    }
    selectedElementIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
    selectedElementId.value = ids.isEmpty ? null : ids.last;
  }

  void clearSelection() {
    selectedElementId.value = null;
    selectedElementIds.clear();
    notifyListeners();
  }

  void copySelected() {
    final selected = selectedElements.where((element) => element.isVisible);
    if (selected.isEmpty) return;
    _clipboard
      ..clear()
      ..addAll(selected.map(_prepareElementForHistory));
  }

  void paste({Offset offset = const Offset(20, 20)}) {
    if (_clipboard.isEmpty) return;

    final pasted = <AnnotationElement>[];
    for (final element in _clipboard) {
      final cloned = element.translated(
        offset,
        preserveId: false,
        zIndex: elements.length + pasted.length,
      );
      pasted.add(_prepareElementForState(cloned));
    }
    if (pasted.isEmpty) return;

    _saveUndoState();
    elements.addAll(pasted);
    notifyListeners();
    _advanceNextCounterFor(pasted);
    selectedElementIds
      ..clear()
      ..addAll(pasted.map((element) => element.id));
    notifyListeners();
    selectedElementId.value = pasted.isEmpty ? null : pasted.last.id;
    _clearRedoStack();
  }

  void deleteSelected() {
    if (selectedElementIds.isEmpty && selectedElementId.value == null) return;

    final idsToRemove = selectedElementIds.isNotEmpty
        ? selectedElementIds.toSet()
        : {selectedElementId.value!};
    final removableIds = elements
        .where((element) {
          return idsToRemove.contains(element.id) && !element.isLocked;
        })
        .map((element) => element.id)
        .toSet();
    if (removableIds.isEmpty) return;

    _saveUndoState();
    elements.removeWhere((element) => removableIds.contains(element.id));
    notifyListeners();
    clearSelection();
    _clearRedoStack();
  }

  void cutSelected() {
    copySelected();
    deleteSelected();
  }

  void bringToFront() {
    final ids = _mutableSelectedIds();
    if (ids.isEmpty) return;
    _saveUndoState();
    final moved = elements.where((e) => ids.contains(e.id)).toList();
    elements.removeWhere((e) => ids.contains(e.id));
    notifyListeners();
    elements.addAll(moved);
    notifyListeners();
    _reindexInPlace();
    _clearRedoStack();
  }

  void sendToBack() {
    final ids = _mutableSelectedIds();
    if (ids.isEmpty) return;
    _saveUndoState();
    final moved = elements.where((e) => ids.contains(e.id)).toList();
    elements.removeWhere((e) => ids.contains(e.id));
    notifyListeners();
    elements.insertAll(0, moved);
    notifyListeners();
    _reindexInPlace();
    _clearRedoStack();
  }

  void bringForward() {
    final ids = _mutableSelectedIds();
    if (ids.isEmpty) return;
    _saveUndoState();
    for (var i = elements.length - 2; i >= 0; i--) {
      if (ids.contains(elements[i].id) && !ids.contains(elements[i + 1].id)) {
        final tmp = elements[i];
        elements[i] = elements[i + 1];
        elements[i + 1] = tmp;
      }
    }
    _reindexInPlace();
    _clearRedoStack();
  }

  void sendBackward() {
    final ids = _mutableSelectedIds();
    if (ids.isEmpty) return;
    _saveUndoState();
    for (var i = 1; i < elements.length; i++) {
      if (ids.contains(elements[i].id) && !ids.contains(elements[i - 1].id)) {
        final tmp = elements[i];
        elements[i] = elements[i - 1];
        elements[i - 1] = tmp;
      }
    }
    _reindexInPlace();
    _clearRedoStack();
  }

  void nudgeSelected(Offset delta) {
    final ids = _mutableSelectedIds();
    if (ids.isEmpty) return;
    for (var i = 0; i < elements.length; i++) {
      if (ids.contains(elements[i].id) && !elements[i].isLocked) {
        elements[i] = elements[i].translated(delta);
      }
    }
    notifyListeners();
  }

  void scaleSelected(double factor) {
    final ids = _mutableSelectedIds();
    if (ids.isEmpty) return;
    _saveUndoState();
    for (var i = 0; i < elements.length; i++) {
      if (ids.contains(elements[i].id) && !elements[i].isLocked) {
        final e = elements[i];
        elements[i] = e.translated(Offset.zero, zIndex: e.zIndex);
      }
    }
    notifyListeners();
    _clearRedoStack();
  }

  void rotateSelected(double radians) {
    final ids = _mutableSelectedIds();
    if (ids.isEmpty) return;
    _saveUndoState();
    for (var i = 0; i < elements.length; i++) {
      if (ids.contains(elements[i].id) && !elements[i].isLocked) {
        final e = elements[i];
        elements[i] = e.translated(Offset.zero, zIndex: e.zIndex);
      }
    }
    notifyListeners();
    _clearRedoStack();
  }

  void alignSelected(AlignmentMode mode) {
    final selected = elements
        .where((e) => selectedElementIds.contains(e.id) && !e.isLocked)
        .toList();
    if (selected.length < 2) return;

    final allBounds = selected.map((e) => e.bounds);
    final unionBounds = allBounds.reduce(
      (a, b) => Rect.fromLTRB(
        a.left < b.left ? a.left : b.left,
        a.top < b.top ? a.top : b.top,
        a.right > b.right ? a.right : b.right,
        a.bottom > b.bottom ? a.bottom : b.bottom,
      ),
    );

    _saveUndoState();
    for (var i = 0; i < elements.length; i++) {
      if (!selectedElementIds.contains(elements[i].id) ||
          elements[i].isLocked) {
        continue;
      }
      final bounds = elements[i].bounds;
      final Offset offset;
      switch (mode) {
        case AlignmentMode.left:
          offset = Offset(unionBounds.left - bounds.left, 0);
        case AlignmentMode.right:
          offset = Offset(unionBounds.right - bounds.right, 0);
        case AlignmentMode.top:
          offset = Offset(0, unionBounds.top - bounds.top);
        case AlignmentMode.bottom:
          offset = Offset(0, unionBounds.bottom - bounds.bottom);
        case AlignmentMode.centerH:
          offset = Offset(unionBounds.center.dx - bounds.center.dx, 0);
        case AlignmentMode.centerV:
          offset = Offset(0, unionBounds.center.dy - bounds.center.dy);
      }
      if (offset != Offset.zero) {
        elements[i] = elements[i].translated(offset);
      }
    }
    notifyListeners();
    _clearRedoStack();
  }

  Set<String> _mutableSelectedIds() {
    if (selectedElementIds.isNotEmpty) return selectedElementIds.toSet();
    final id = selectedElementId.value;
    return id == null ? const {} : {id};
  }

  void _reindexInPlace() {
    for (var i = 0; i < elements.length; i++) {
      elements[i] = elements[i].translated(Offset.zero, zIndex: i);
    }
    notifyListeners();
  }

  void eraseAt(Offset point) {
    for (final element in elements.reversed) {
      if (!element.isLocked && element.hitTest(point)) {
        _saveUndoState();
        elements.removeWhere((candidate) => candidate.id == element.id);
        notifyListeners();
        _pruneSelection();
        _clearRedoStack();
        return;
      }
    }
  }

  void eraseAlongPath(List<Offset> points) {
    final idsToRemove = <String>{};
    for (final point in points) {
      for (final element in elements) {
        if (!element.isLocked && element.hitTest(point)) {
          idsToRemove.add(element.id);
        }
      }
    }
    if (idsToRemove.isEmpty) return;

    _saveUndoState();
    elements.removeWhere((element) => idsToRemove.contains(element.id));
    notifyListeners();
    _pruneSelection();
    _clearRedoStack();
  }

  void applyCrop({required Uint8List imageBytes, required Rect cropRect}) {
    if (cropRect.isEmpty) return;
    final originOffset = Offset(-cropRect.left, -cropRect.top);
    final croppedElements = _reindexElements(
      elements.map((element) {
        return _prepareElementForState(element.translated(originOffset));
      }).toList(),
    );
    _saveUndoState();
    backgroundImage.value = imageBytes;
    imageSize.value = cropRect.size;
    elements
      ..clear()
      ..addAll(croppedElements);
    notifyListeners();

    _clearRedoStack();
    nextCounter.value = _nextCounterFor(croppedElements);
    clearSelection();
  }

  void updateAlignmentGuides(AnnotationElement dragged) {
    const snapThreshold = 5.0;
    final guides = <AlignmentGuide>[];
    final dragBounds = dragged.bounds;

    for (final element in elements) {
      if (element.id == dragged.id || !element.isVisible) continue;
      final targetBounds = element.bounds;

      for (final dragY in [
        dragBounds.top,
        dragBounds.center.dy,
        dragBounds.bottom,
      ]) {
        for (final targetY in [
          targetBounds.top,
          targetBounds.center.dy,
          targetBounds.bottom,
        ]) {
          if ((dragY - targetY).abs() < snapThreshold) {
            guides.add(AlignmentGuide(position: targetY, isHorizontal: true));
          }
        }
      }

      for (final dragX in [
        dragBounds.left,
        dragBounds.center.dx,
        dragBounds.right,
      ]) {
        for (final targetX in [
          targetBounds.left,
          targetBounds.center.dx,
          targetBounds.right,
        ]) {
          if ((dragX - targetX).abs() < snapThreshold) {
            guides.add(AlignmentGuide(position: targetX, isHorizontal: false));
          }
        }
      }
    }

    alignmentGuides
      ..clear()
      ..addAll(guides);

    notifyListeners();
  }

  void clearAlignmentGuides() {
    alignmentGuides.clear();
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final previousState = _undoStack.removeLast();
    _redoStack.add(_snapshotState());
    _restoreHistoryEntry(previousState);
    _pruneHistoryResources();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final nextState = _redoStack.removeLast();
    _undoStack.add(_snapshotState());
    _restoreHistoryEntry(nextState);
    _pruneHistoryResources();
  }

  Map<String, dynamic> toJson() {
    return {
      'elements': elements.map((element) => element.toJson()).toList(),
      'currentTool': currentTool.value.name,
      'currentColor': currentColor.value.toARGB32(),
      'currentFillColor': currentFillColor.value.toARGB32(),
      'useFillColor': useFillColor.value,
      'currentOpacity': currentOpacity.value,
      'currentStrokeWidth': currentStrokeWidth.value,
      'currentFontSize': currentFontSize.value,
      'nextCounter': nextCounter.value,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final rawElements = json['elements'] as List<dynamic>? ?? const [];
    final parsedElements = rawElements
        .whereType<Map>()
        .map((rawElement) {
          return AnnotationElementJson.fromJson(
            Map<String, dynamic>.from(rawElement),
          );
        })
        .whereType<AnnotationElement>()
        .toList();

    final loadedElements = _reindexElements(
      parsedElements.map(_prepareElementForState).toList(),
    );
    elements
      ..clear()
      ..addAll(loadedElements);
    notifyListeners();

    currentTool.value = AnnotateTool.values.firstWhere(
      (tool) => tool.name == json['currentTool'],
      orElse: () => AnnotateTool.arrow,
    );
    currentColor.value = _colorFromJson(
      json['currentColor'],
      const Color(0xFFE11D48),
    );
    currentFillColor.value = _colorFromJson(
      json['currentFillColor'],
      const Color(0xFFE11D48),
    );
    useFillColor.value = json['useFillColor'] is bool
        ? json['useFillColor'] as bool
        : false;
    currentOpacity.value = _doubleFromJson(
      json['currentOpacity'],
      1,
    ).clamp(0.15, 1.0).toDouble();
    currentStrokeWidth.value = _doubleFromJson(
      json['currentStrokeWidth'],
      2,
    ).clamp(1.0, 64.0).toDouble();
    currentFontSize.value = _doubleFromJson(
      json['currentFontSize'],
      16,
    ).clamp(6.0, 256.0).toDouble();
    final minimumNextCounter = _nextCounterFor(loadedElements);
    final parsedNextCounter = _intFromJson(
      json['nextCounter'],
      minimumNextCounter,
    );
    nextCounter.value = parsedNextCounter < minimumNextCounter
        ? minimumNextCounter
        : parsedNextCounter;
    _undoStack.clear();
    _redoStack.clear();
    _clipboard.clear();
    _historyResourcePool.clear();
    clearSelection();
  }

  bool _replaceElement(String id, AnnotationElement updated) {
    final index = elements.indexWhere((element) => element.id == id);
    if (index == -1) return false;
    elements[index] = _prepareElementForState(updated);
    notifyListeners();

    return true;
  }

  void _saveUndoState() {
    _undoStack.add(_snapshotState());
    if (_undoStack.length > maxUndoStackDepth) {
      _undoStack.removeAt(0);
      _pruneHistoryResources();
    }
  }

  _AnnotationHistoryEntry _snapshotState() {
    return _AnnotationHistoryEntry(
      elements: _cloneElementsForHistory(elements),
      backgroundImage: backgroundImage.value,
      imageSize: imageSize.value,
      nextCounter: nextCounter.value,
    );
  }

  void _restoreHistoryEntry(_AnnotationHistoryEntry entry) {
    backgroundImage.value = entry.backgroundImage;
    imageSize.value = entry.imageSize;
    elements
      ..clear()
      ..addAll(_cloneElementsForHistory(entry.elements));
    notifyListeners();

    nextCounter.value = entry.nextCounter;
    clearAlignmentGuides();
    clearSelection();
    notifyListeners();
  }

  void _clearRedoStack() {
    if (_redoStack.isEmpty) return;
    _redoStack.clear();
    _pruneHistoryResources();
  }

  void _pruneSelection() {
    final existingIds = elements.map((element) => element.id).toSet();
    selectedElementIds.removeWhere((id) => !existingIds.contains(id));
    notifyListeners();
    final selectedId = selectedElementId.value;
    if (selectedId != null && !existingIds.contains(selectedId)) {
      selectedElementId.value = selectedElementIds.isEmpty
          ? null
          : selectedElementIds.last;
    }
  }

  void _advanceNextCounterFor(Iterable<AnnotationElement> source) {
    final candidate = _nextCounterFor(source);
    if (candidate > nextCounter.value) {
      nextCounter.value = candidate;
    }
  }

  AnnotationElement? _elementById(String id) {
    for (final element in elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  bool _hasTransformableSelection() {
    if (selectedElementIds.isNotEmpty) {
      return elements.any((element) {
        return selectedElementIds.contains(element.id) && !element.isLocked;
      });
    }
    final selectedId = selectedElementId.value;
    if (selectedId == null) return false;
    final selected = _elementById(selectedId);
    return selected != null && !selected.isLocked;
  }

  List<AnnotationElement> _cloneElementsForHistory(
    Iterable<AnnotationElement> source,
  ) {
    return source.map(_prepareElementForHistory).toList();
  }

  AnnotationElement _prepareElementForState(AnnotationElement element) {
    return _prepareElementForHistory(element);
  }

  AnnotationElement _prepareElementForHistory(AnnotationElement element) {
    if (element is FreeDrawElement) {
      final points = _limitFreeDrawPoints(element.points);
      return FreeDrawElement(
        id: element.id,
        points: points,
        color: element.color,
        strokeWidth: element.strokeWidth,
        isHighlighter: element.isHighlighter,
        rotation: element.rotation,
        scale: element.scale,
        zIndex: element.zIndex,
        isLocked: element.isLocked,
        isVisible: element.isVisible,
      );
    }

    if (element is StickerElement) {
      final dataBase64 = _historyResourcePool.internBase64(
        element.dataBase64,
        maxBytes: _maxInlineStickerImageBytes,
      );
      final svgContent = _historyResourcePool.internText(
        element.svgContent,
        maxBytes: _maxInlineStickerSvgBytes,
      );
      return StickerElement(
        id: element.id,
        stickerId: element.stickerId,
        name: element.name,
        assetPath: element.assetPath,
        rect: element.rect,
        format: element.format,
        tintColor: element.tintColor,
        svgContent: svgContent,
        dataBase64: dataBase64,
        resourceId: element.resourceId,
        resourceHash: element.resourceHash,
        isRecolorable: element.isRecolorable,
        isFlippedH: element.isFlippedH,
        isFlippedV: element.isFlippedV,
        rotation: element.rotation,
        scale: element.scale,
        zIndex: element.zIndex,
        isLocked: element.isLocked,
        isVisible: element.isVisible,
      );
    }

    return element.clone();
  }

  List<Offset> _limitFreeDrawPoints(List<Offset> points) {
    if (points.length <= maxFreeDrawPoints) return List.unmodifiable(points);
    if (maxFreeDrawPoints <= 1) return [points.first];

    final lastIndex = points.length - 1;
    final limited = <Offset>[];
    for (var index = 0; index < maxFreeDrawPoints; index += 1) {
      final sourceIndex = (index * lastIndex / (maxFreeDrawPoints - 1)).round();
      limited.add(points[sourceIndex]);
    }
    return List.unmodifiable(limited);
  }

  void _pruneHistoryResources() {
    final retained = <AnnotationElement>[
      ...elements,
      ..._clipboard,
      for (final entry in _undoStack) ...entry.elements,
      for (final entry in _redoStack) ...entry.elements,
    ];
    _historyResourcePool.retain(retained.whereType<StickerElement>());
  }

  List<AnnotationElement> _reindexElements(List<AnnotationElement> source) {
    final ordered =
        [
          for (var index = 0; index < source.length; index += 1)
            MapEntry(index, source[index]),
        ]..sort((a, b) {
          final zIndexCompare = a.value.zIndex.compareTo(b.value.zIndex);
          if (zIndexCompare != 0) return zIndexCompare;
          return a.key.compareTo(b.key);
        });
    return [
      for (var index = 0; index < ordered.length; index += 1)
        ordered[index].value.translated(Offset.zero, zIndex: index),
    ];
  }

  int _nextCounterFor(Iterable<AnnotationElement> source) {
    final counters = source.whereType<CounterElement>();
    if (counters.isEmpty) return 1;
    return counters
            .map((counter) => counter.number)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  double _doubleFromJson(Object? value, double fallback) {
    final parsed = value is num ? value.toDouble() : fallback;
    return parsed.isFinite ? parsed : fallback;
  }

  Color _colorFromJson(Object? value, Color fallback) {
    if (value is! num || !value.toDouble().isFinite) return fallback;
    return Color(value.toInt());
  }

  int _intFromJson(Object? value, int fallback) {
    if (value is! num || !value.toDouble().isFinite) return fallback;
    return value.toInt();
  }
}

class _AnnotationHistoryEntry {
  final List<AnnotationElement> elements;
  final Uint8List? backgroundImage;
  final Size? imageSize;
  final int nextCounter;

  const _AnnotationHistoryEntry({
    required this.elements,
    required this.backgroundImage,
    required this.imageSize,
    required this.nextCounter,
  });
}

class _AnnotationHistoryResourcePool {
  final Map<String, String> _base64Resources = {};
  final Map<String, String> _textResources = {};

  void clear() {
    _base64Resources.clear();
    _textResources.clear();
  }

  void retain(Iterable<StickerElement> elements) {
    final retainedBase64 = <String>{};
    final retainedText = <String>{};
    for (final element in elements) {
      final dataBase64 = element.dataBase64;
      if (dataBase64 != null && dataBase64.isNotEmpty) {
        retainedBase64.add(dataBase64);
      }
      final svgContent = element.svgContent;
      if (svgContent != null && svgContent.isNotEmpty) {
        retainedText.add(svgContent);
      }
    }
    _base64Resources.removeWhere((key, value) => !retainedBase64.contains(key));
    _textResources.removeWhere((key, value) => !retainedText.contains(key));
  }

  String? internBase64(String? value, {required int maxBytes}) {
    if (value == null || value.isEmpty) return value;
    final byteLength = _decodedBase64Length(value);
    if (byteLength > maxBytes) {
      throw ArgumentError.value(
        byteLength,
        'dataBase64',
        'Inline sticker image exceeds the annotation resource budget.',
      );
    }
    return _base64Resources.putIfAbsent(value, () => value);
  }

  String? internText(String? value, {required int maxBytes}) {
    if (value == null || value.isEmpty) return value;
    final byteLength = utf8.encode(value).length;
    if (byteLength > maxBytes) {
      throw ArgumentError.value(
        byteLength,
        'svgContent',
        'Inline sticker SVG exceeds the annotation resource budget.',
      );
    }
    return _textResources.putIfAbsent(value, () => value);
  }

  int _decodedBase64Length(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 0;
    final padding = normalized.endsWith('==')
        ? 2
        : normalized.endsWith('=')
        ? 1
        : 0;
    return (normalized.length * 3 ~/ 4) - padding;
  }
}
