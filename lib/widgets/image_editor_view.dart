import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../src/background/background_composer.dart';
import '../src/background/background_controller.dart';
import '../src/background/background_state.dart';
import '../src/canvas/annotation_canvas.dart';
import '../src/canvas/annotation_controller.dart';
import '../src/canvas/annotation_element.dart';
import '../src/core/app_result.dart';
import '../src/core/image_editor_localizations.dart';
import '../src/project/project_file.dart';
import '../src/stickers/sticker_asset.dart';
import '../src/stickers/sticker_library.dart';
import '../src/stickers/sticker_render_cache.dart';
import '../src/tools/tool_types.dart';
import 'annotation_toolbar.dart';
import 'background_editor.dart';
import 'sticker_panel.dart';

class ExportResult {
  final Uint8List imageBytes;
  final ProjectSnapshot snapshot;
  final AppFailure? failure;

  const ExportResult({
    required this.imageBytes,
    required this.snapshot,
    this.failure,
  });

  bool get isSuccess => failure == null;

  bool get isFailure => failure != null;
}

class ImageEditorView extends StatefulWidget {
  final Uint8List imageBytes;
  final Size imageSize;
  final List<AnnotationElement> initialElements;
  final BackgroundState initialBackground;
  final AnnotationController? annotationController;
  final BackgroundController? backgroundController;
  final ImageEditorTools tools;
  final StickerLibraryController? stickerLibrary;
  final StickerRenderCache? stickerRenderCache;
  final ImageEditorLocalizations localizations;
  final ValueChanged<ExportResult>? onExport;
  final ValueChanged<ProjectSnapshot>? onSave;
  final ValueChanged<AnnotationController>? onChanged;

  const ImageEditorView({
    super.key,
    required this.imageBytes,
    required this.imageSize,
    this.initialElements = const [],
    this.initialBackground = const BackgroundState(),
    this.annotationController,
    this.backgroundController,
    this.tools = const ImageEditorTools({}),
    this.stickerLibrary,
    this.stickerRenderCache,
    this.localizations = const DefaultImageEditorLocalizations(),
    this.onExport,
    this.onSave,
    this.onChanged,
  });

  @override
  State<ImageEditorView> createState() => _ImageEditorViewState();
}

class _ImageEditorViewState extends State<ImageEditorView> {
  late AnnotationController _annotationController;
  late BackgroundController _backgroundController;
  late StickerLibraryController _stickerLibraryController;
  late StickerRenderCache _stickerRenderCache;
  late bool _ownsAnnotationController;
  late bool _ownsBackgroundController;
  late bool _ownsStickerLibraryController;
  late bool _ownsStickerRenderCache;
  AnnotationController? _observedController;
  var _isLoadingInitialState = false;
  var _isExporting = false;

  @override
  void initState() {
    super.initState();
    _ownsAnnotationController = widget.annotationController == null;
    _annotationController =
        widget.annotationController ?? AnnotationController();
    _ownsBackgroundController = widget.backgroundController == null;
    _backgroundController =
        widget.backgroundController ?? BackgroundController();
    _ownsStickerLibraryController = widget.stickerLibrary == null;
    _stickerLibraryController =
        widget.stickerLibrary ?? StickerLibraryController();
    _ownsStickerRenderCache = widget.stickerRenderCache == null;
    _stickerRenderCache = widget.stickerRenderCache ?? StickerRenderCache();
    _loadInitialState();
    _attachChangeWorkers();
  }

  @override
  void didUpdateWidget(covariant ImageEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final annotationControllerChanged =
        oldWidget.annotationController != widget.annotationController;
    final backgroundControllerChanged =
        oldWidget.backgroundController != widget.backgroundController;
    final stickerLibraryChanged =
        oldWidget.stickerLibrary != widget.stickerLibrary;
    final stickerRenderCacheChanged =
        oldWidget.stickerRenderCache != widget.stickerRenderCache;

    if (annotationControllerChanged) {
      _disposeOwnedController(_annotationController, _ownsAnnotationController);
      _ownsAnnotationController = widget.annotationController == null;
      _annotationController =
          widget.annotationController ?? AnnotationController();
    }
    if (backgroundControllerChanged) {
      _disposeOwnedController(_backgroundController, _ownsBackgroundController);
      _ownsBackgroundController = widget.backgroundController == null;
      _backgroundController =
          widget.backgroundController ?? BackgroundController();
    }
    if (stickerLibraryChanged) {
      _disposeOwnedController(
        _stickerLibraryController,
        _ownsStickerLibraryController,
      );
      _ownsStickerLibraryController = widget.stickerLibrary == null;
      _stickerLibraryController =
          widget.stickerLibrary ?? StickerLibraryController();
    }
    if (stickerRenderCacheChanged) {
      if (_ownsStickerRenderCache) {
        _stickerRenderCache.dispose();
      }
      _ownsStickerRenderCache = widget.stickerRenderCache == null;
      _stickerRenderCache = widget.stickerRenderCache ?? StickerRenderCache();
    }

    final shouldReloadAnnotations =
        annotationControllerChanged ||
        oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.imageSize != widget.imageSize ||
        oldWidget.initialElements != widget.initialElements;
    final shouldReloadBackground =
        backgroundControllerChanged ||
        oldWidget.initialBackground != widget.initialBackground;

    if (shouldReloadAnnotations || shouldReloadBackground) {
      _isLoadingInitialState = true;
      try {
        if (shouldReloadAnnotations) {
          _loadAnnotationInitialState(clearStickerCache: true);
        }
        if (shouldReloadBackground) {
          _loadBackgroundInitialState();
        }
      } finally {
        _isLoadingInitialState = false;
      }
    }
    if (annotationControllerChanged ||
        oldWidget.onChanged != widget.onChanged) {
      _attachChangeWorkers();
    }
  }

  @override
  void dispose() {
    _disposeChangeWorkers();
    if (_ownsStickerRenderCache) {
      _stickerRenderCache.dispose();
    }
    _disposeOwnedController(
      _stickerLibraryController,
      _ownsStickerLibraryController,
    );
    _disposeOwnedController(_backgroundController, _ownsBackgroundController);
    _disposeOwnedController(_annotationController, _ownsAnnotationController);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: [
          _EditorCommandBar(
            localizations: widget.localizations,
            onSave: widget.onSave == null ? null : _handleSave,
            onExport: widget.onExport == null || _isExporting
                ? null
                : _handleExport,
            isExporting: _isExporting,
          ),
          Expanded(
            child: Row(
              children: [
                AnnotationToolbar(
                  controller: _annotationController,
                  tools: widget.tools,
                  localizations: widget.localizations,
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AnnotationCanvas(
                        imageBytes: widget.imageBytes,
                        imageSize: widget.imageSize,
                        controller: _annotationController,
                        stickerRenderCache: _stickerRenderCache,
                        localizations: widget.localizations,
                      ),
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: _annotationController,
                  builder: (context, _) {
                    final tool = _annotationController.currentTool.value;
                    if (tool == AnnotateTool.sticker) {
                      return StickerPanel(
                        controller: _stickerLibraryController,
                        localizations: widget.localizations,
                        onStickerInserted: _insertSticker,
                      );
                    }
                    return BackgroundEditor(
                      controller: _backgroundController,
                      localizations: widget.localizations,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadInitialState() {
    _isLoadingInitialState = true;
    try {
      _loadAnnotationInitialState(clearStickerCache: false);
      _loadBackgroundInitialState();
    } finally {
      _isLoadingInitialState = false;
    }
  }

  void _loadAnnotationInitialState({required bool clearStickerCache}) {
    if (clearStickerCache) {
      _stickerRenderCache.clear();
    }
    _annotationController.loadProject(
      imageBytes: widget.imageBytes,
      imageSize: widget.imageSize,
      elements: widget.initialElements,
    );
  }

  void _loadBackgroundInitialState() {
    _backgroundController.replace(widget.initialBackground);
  }

  void _insertSticker(StickerAsset sticker) {
    final currentImageSize =
        _annotationController.imageSize.value ?? widget.imageSize;
    final safeWidth = math.max(currentImageSize.width, 1.0);
    final safeHeight = math.max(currentImageSize.height, 1.0);
    final maxStickerSize = math.min(safeWidth, safeHeight);
    final stickerSize = (maxStickerSize * 0.3)
        .clamp(1.0, maxStickerSize)
        .toDouble();
    _annotationController.addElement(
      StickerElement(
        stickerId: sticker.id,
        name: sticker.name,
        assetPath: sticker.assetPath,
        rect: Rect.fromLTWH(
          (safeWidth - stickerSize) / 2,
          (safeHeight - stickerSize) / 2,
          stickerSize,
          stickerSize,
        ),
        format: sticker.format == StickerAssetFormat.png
            ? StickerFormat.png
            : StickerFormat.svg,
        svgContent: sticker.svgContent,
        dataBase64: sticker.dataBase64,
        resourceId: sticker.resourceId,
        resourceHash: sticker.resourceHash,
        isRecolorable: sticker.isRecolorable,
        tintColor: _annotationController.currentColor.value,
      ),
    );
  }

  ProjectSnapshot _snapshot() {
    final currentImageBytes =
        _annotationController.backgroundImage.value ?? widget.imageBytes;
    final currentImageSize =
        _annotationController.imageSize.value ?? widget.imageSize;
    return ProjectSnapshot(
      elements: _annotationController.elements.toList(),
      backgroundState: _backgroundController.state.value,
      imageRef: ProjectImageRef(
        id: 'source',
        bytes: currentImageBytes,
        size: currentImageSize,
      ),
    );
  }

  void _handleSave() {
    widget.onSave?.call(_snapshot());
  }

  Future<void> _handleExport() async {
    if (_isExporting || widget.onExport == null) return;
    setState(() {
      _isExporting = true;
    });
    final snapshot = _snapshot();
    final stickerRenderCache = _stickerRenderCache;
    try {
      await stickerRenderCache.preloadAll(snapshot.elements);
      if (!mounted) return;
      final imageBytes = snapshot.imageRef.bytes;
      final imageSize = snapshot.imageRef.size;
      if (imageBytes == null || imageSize == null) {
        widget.onExport?.call(
          ExportResult(
            imageBytes: Uint8List(0),
            snapshot: snapshot,
            failure: AppFailure(
              code: AppFailureCode.invalidInput,
              message: widget.localizations.text('error.compositeImageFailed'),
              recoverySuggestion: widget.localizations.text('error.tryAgain'),
            ),
          ),
        );
        return;
      }
      final result = await BackgroundComposer.compose(
        imageBytes: imageBytes,
        imageSize: imageSize,
        backgroundState: snapshot.backgroundState,
        localizations: widget.localizations,
        paintAnnotations: (canvas, size) {
          AnnotationCanvasPainter(
            elements: snapshot.elements,
            selectionColor: const Color(0xFF6366F1),
            stickerRenderCache: stickerRenderCache,
            localizations: widget.localizations,
            showSelectionHandles: false,
          ).paint(canvas, size);
        },
      );
      if (!mounted) return;
      widget.onExport?.call(
        ExportResult(
          imageBytes: result.value ?? Uint8List(0),
          snapshot: snapshot,
          failure: result.failure,
        ),
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      widget.onExport?.call(
        ExportResult(
          imageBytes: Uint8List(0),
          snapshot: snapshot,
          failure: AppFailure(
            code: AppFailureCode.unknown,
            message: widget.localizations.text('error.compositeImageFailed'),
            recoverySuggestion: widget.localizations.text('error.tryAgain'),
            cause: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _attachChangeWorkers() {
    _disposeChangeWorkers();
    if (widget.onChanged == null) return;
    _observedController = _annotationController;
    _observedController!.addListener(_notifyAnnotationChanged);
  }

  void _notifyAnnotationChanged() {
    if (!_isLoadingInitialState && mounted) {
      widget.onChanged?.call(_annotationController);
    }
  }

  void _disposeChangeWorkers() {
    _observedController?.removeListener(_notifyAnnotationChanged);
    _observedController = null;
  }

  void _disposeOwnedController(ChangeNotifier controller, bool ownsController) {
    if (!ownsController) return;
    controller.dispose();
  }
}

class _EditorCommandBar extends StatelessWidget {
  final ImageEditorLocalizations localizations;
  final VoidCallback? onSave;
  final VoidCallback? onExport;
  final bool isExporting;

  const _EditorCommandBar({
    required this.localizations,
    required this.onSave,
    required this.onExport,
    required this.isExporting,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 12),
            IconButton(
              tooltip: localizations.text('common.save'),
              icon: const Icon(Icons.save_outlined),
              onPressed: onSave,
            ),
            IconButton(
              tooltip: localizations.text('common.export'),
              icon: isExporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              onPressed: onExport,
            ),
          ],
        ),
      ),
    );
  }
}
