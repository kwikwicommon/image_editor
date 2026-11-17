import 'dart:typed_data';
import 'dart:ui';

import '../canvas/annotation_element.dart';

/// Immutable snapshot of annotation state for compositing.
/// Host applications receive this to composite annotations
/// onto the full-resolution source image.
class AnnotationRenderSnapshot {
  final int schemaVersion;
  final List<AnnotationElement> elements;
  final Size canvasSize;
  final Uint8List? rasterizedRgba;
  final int? rasterizedWidth;
  final int? rasterizedHeight;
  final DateTime capturedAt;

  const AnnotationRenderSnapshot({
    required this.schemaVersion,
    required this.elements,
    required this.canvasSize,
    this.rasterizedRgba,
    this.rasterizedWidth,
    this.rasterizedHeight,
    required this.capturedAt,
  });

  bool get hasRasterData =>
      rasterizedRgba != null &&
      rasterizedWidth != null &&
      rasterizedHeight != null;
}

/// Capability configuration for controlling which tools and features
/// are available in the editor. Host applications use this to hide
/// non-first-version tools without removing public package code.
class EditorCapabilities {
  final bool enableStickers;
  final bool enableCrop;
  final bool enableBlur;
  final bool enableSpotlight;
  final bool enableText;
  final bool enableCounter;
  final bool enableHighlighter;
  final bool enableArrow;
  final bool enableShape;
  final bool enableFreeDraw;
  final bool enableEraser;
  final bool enableLine;
  final bool enableFill;
  final bool enableColorPicker;
  final bool enableSolidRedaction;
  final int maxUndoDepth;
  final int maxFreeDrawPoints;

  const EditorCapabilities({
    this.enableStickers = true,
    this.enableCrop = true,
    this.enableBlur = true,
    this.enableSpotlight = true,
    this.enableText = true,
    this.enableCounter = true,
    this.enableHighlighter = true,
    this.enableArrow = true,
    this.enableShape = true,
    this.enableFreeDraw = true,
    this.enableEraser = true,
    this.enableLine = true,
    this.enableFill = false,
    this.enableColorPicker = true,
    this.enableSolidRedaction = true,
    this.maxUndoDepth = 50,
    this.maxFreeDrawPoints = 12000,
  });

  static const goodImageV1 = EditorCapabilities(
    enableStickers: false,
    enableFill: false,
  );
}

/// Sink interface for the host application to receive annotation
/// operations without coupling to AnnotationController's GetX history.
abstract class AnnotationOperationSink {
  void onAnnotationsChanged(List<AnnotationElement> elements);

  void onAnnotationAdded(AnnotationElement element);

  void onAnnotationRemoved(String elementId);

  void onAnnotationUpdated(String elementId, AnnotationElement updated);

  void onUndoRedo({required bool isUndo, required int remainingUndos});

  AnnotationRenderSnapshot captureSnapshot();
}

/// Adapter interface for host applications to integrate the annotation
/// system with their own document model and version graph.
abstract class ImageEditorDocumentAdapter {
  /// Submit an immutable snapshot as a new version in the host's history.
  void commitAnnotationVersion(AnnotationRenderSnapshot snapshot);

  /// Request the host to save annotation resources via its persistence.
  Future<String> saveResource(String resourceId, Uint8List bytes);

  /// Request the host to load annotation resources.
  Future<Uint8List?> loadResource(String resourceId);

  /// Notify the host that the annotation state is dirty.
  void markDirty();

  /// Get the current canvas size from the host document.
  Size get canvasSize;
}
