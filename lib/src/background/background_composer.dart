import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/app_result.dart';
import '../core/image_editor_localizations.dart';
import 'background_state.dart';
import 'background_layout.dart';
import 'image_background_placeholder_painter.dart';
import 'pattern_painter.dart';

typedef AnnotationPaintCallback = void Function(Canvas canvas, Size imageSize);

class BackgroundCompositionBudget {
  final double maxPixelRatio;
  final int maxOutputWidth;
  final int maxOutputHeight;
  final int maxOutputPixels;
  final int maxEstimatedMemoryBytes;

  const BackgroundCompositionBudget({
    this.maxPixelRatio = 4,
    this.maxOutputWidth = 16384,
    this.maxOutputHeight = 16384,
    this.maxOutputPixels = 67108864,
    this.maxEstimatedMemoryBytes = 512 * 1024 * 1024,
  });
}

class _DecodedImage {
  final ui.Image image;

  const _DecodedImage(this.image);
}

class _OutputBudgetMetrics {
  final double pixelRatio;
  final int outputWidth;
  final int outputHeight;

  const _OutputBudgetMetrics({
    required this.pixelRatio,
    required this.outputWidth,
    required this.outputHeight,
  });
}

class BackgroundComposer {
  const BackgroundComposer._();

  static const BackgroundCompositionBudget defaultBudget =
      BackgroundCompositionBudget();

  static Future<AppResult<Uint8List>> compose({
    required Uint8List imageBytes,
    required Size imageSize,
    required BackgroundState backgroundState,
    required AnnotationPaintCallback paintAnnotations,
    double pixelRatio = 1,
    BackgroundCompositionBudget budget = defaultBudget,
    ImageEditorLocalizations localizations =
        const DefaultImageEditorLocalizations(),
  }) async {
    ui.Image? sourceImage;
    ui.Image? customBackgroundImage;
    ui.Picture? picture;
    ui.Image? outputImage;

    try {
      final safeState = backgroundState.normalized();
      final sourceResult = await _decodeImage(
        imageBytes,
        failureMessage: localizations.text('error.invalidSourceImage'),
        recoverySuggestion: localizations.text('error.importReadableImage'),
      );
      if (sourceResult.isFailure) {
        return AppResult.failure(sourceResult.requireFailure);
      }
      sourceImage = sourceResult.requireValue.image;

      if (safeState.type == BackgroundType.image &&
          safeState.customImageBytes != null) {
        final customResult = await _decodeImage(
          safeState.customImageBytes,
          failureMessage: localizations.text('error.invalidBackgroundImage'),
          recoverySuggestion: localizations.text(
            'error.importReadableBackgroundImage',
          ),
        );
        if (customResult.isFailure) {
          return AppResult.failure(customResult.requireFailure);
        }
        customBackgroundImage = customResult.requireValue.image;
      }

      final BackgroundLayoutMetrics layout;
      try {
        layout = BackgroundLayoutResolver.resolve(
          imageSize: imageSize,
          backgroundState: safeState,
        );
      } catch (error, stackTrace) {
        return AppResult.failure(
          AppFailure(
            code: AppFailureCode.invalidInput,
            message: localizations.text('error.backgroundLayoutFailed'),
            recoverySuggestion: localizations.text(
              'error.checkBackgroundSettings',
            ),
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }

      final budgetResult = _validateOutputBudget(
        layout: layout,
        pixelRatio: pixelRatio,
        budget: budget,
        localizations: localizations,
        sourceBytes: imageBytes,
        customBackgroundBytes: safeState.type == BackgroundType.image
            ? safeState.customImageBytes
            : null,
        sourceDecodedBytes: _estimatedDecodedImageBytes(sourceImage),
        customBackgroundDecodedBytes: customBackgroundImage == null
            ? 0
            : _estimatedDecodedImageBytes(customBackgroundImage),
      );
      if (budgetResult.isFailure) {
        return AppResult.failure(budgetResult.requireFailure);
      }
      final outputMetrics = budgetResult.requireValue;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(outputMetrics.pixelRatio);

      _paintBackground(
        canvas,
        layout.outputSize,
        safeState,
        customBackgroundImage,
      );
      _paintWindow(canvas, layout, safeState, sourceImage);
      _paintAnnotations(canvas, layout, imageSize, safeState, paintAnnotations);

      picture = recorder.endRecording();
      try {
        outputImage = await picture.toImage(
          outputMetrics.outputWidth,
          outputMetrics.outputHeight,
        );
      } catch (error, stackTrace) {
        return AppResult.failure(
          AppFailure(
            code: AppFailureCode.platform,
            message: localizations.text('error.compositedImageRenderFailed'),
            recoverySuggestion: localizations.text(
              'error.reduceCompositionSize',
            ),
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }

      final ByteData? byteData;
      try {
        byteData = await outputImage.toByteData(format: ui.ImageByteFormat.png);
      } catch (error, stackTrace) {
        return AppResult.failure(
          AppFailure(
            code: AppFailureCode.serialization,
            message: localizations.text('error.compositedImageEncodeFailed'),
            recoverySuggestion: localizations.text(
              'error.reduceCompositionSize',
            ),
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }

      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        return AppResult.failure(
          AppFailure(
            code: AppFailureCode.serialization,
            message: localizations.text('error.compositedImageEncodeFailed'),
            recoverySuggestion: localizations.text(
              'error.reduceCompositionSize',
            ),
          ),
        );
      }

      return AppResult.success(bytes);
    } catch (error, stackTrace) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.unknown,
          message: localizations.text('error.compositeImageFailed'),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      outputImage?.dispose();
      picture?.dispose();
      sourceImage?.dispose();
      customBackgroundImage?.dispose();
    }
  }

  @Deprecated('Use compose for structured failure details.')
  static Future<AppResult<Uint8List>> composeResult({
    required Uint8List imageBytes,
    required Size imageSize,
    required BackgroundState backgroundState,
    required AnnotationPaintCallback paintAnnotations,
    double pixelRatio = 1,
    BackgroundCompositionBudget budget = defaultBudget,
  }) {
    return compose(
      imageBytes: imageBytes,
      imageSize: imageSize,
      backgroundState: backgroundState,
      paintAnnotations: paintAnnotations,
      pixelRatio: pixelRatio,
      budget: budget,
    );
  }

  @Deprecated('Use compose and inspect AppResult.')
  static Future<Uint8List?> composeOrNull({
    required Uint8List imageBytes,
    required Size imageSize,
    required BackgroundState backgroundState,
    required AnnotationPaintCallback paintAnnotations,
    double pixelRatio = 1,
    BackgroundCompositionBudget budget = defaultBudget,
  }) async {
    final result = await compose(
      imageBytes: imageBytes,
      imageSize: imageSize,
      backgroundState: backgroundState,
      paintAnnotations: paintAnnotations,
      pixelRatio: pixelRatio,
      budget: budget,
    );
    return result.value;
  }

  static Future<AppResult<_DecodedImage>> _decodeImage(
    Uint8List? bytes, {
    required String failureMessage,
    required String recoverySuggestion,
  }) async {
    if (bytes == null || bytes.isEmpty) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: failureMessage,
          recoverySuggestion: recoverySuggestion,
        ),
      );
    }
    ui.Codec? codec;

    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return AppResult.success(_DecodedImage(frame.image));
    } catch (error, stackTrace) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: failureMessage,
          recoverySuggestion: recoverySuggestion,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      codec?.dispose();
    }
  }

  static AppResult<_OutputBudgetMetrics> _validateOutputBudget({
    required BackgroundLayoutMetrics layout,
    required double pixelRatio,
    required BackgroundCompositionBudget budget,
    required ImageEditorLocalizations localizations,
    required Uint8List sourceBytes,
    required Uint8List? customBackgroundBytes,
    required int sourceDecodedBytes,
    required int customBackgroundDecodedBytes,
  }) {
    if (!budget.maxPixelRatio.isFinite ||
        budget.maxPixelRatio <= 0 ||
        budget.maxOutputWidth <= 0 ||
        budget.maxOutputHeight <= 0 ||
        budget.maxOutputPixels <= 0 ||
        budget.maxEstimatedMemoryBytes <= 0) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.text('error.invalidCompositionBudget'),
          recoverySuggestion: localizations.text(
            'error.checkBackgroundSettings',
          ),
        ),
      );
    }
    if (!pixelRatio.isFinite || pixelRatio <= 0) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.text('error.invalidCompositionPixelRatio'),
          recoverySuggestion: localizations.text('error.reduceCompositionSize'),
        ),
      );
    }
    if (pixelRatio > budget.maxPixelRatio) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.params('error.compositionPixelRatioTooLarge', {
            'ratio': pixelRatio.toStringAsFixed(2),
            'limit': budget.maxPixelRatio.toStringAsFixed(2),
          }),
          recoverySuggestion: localizations.text('error.reduceCompositionSize'),
        ),
      );
    }

    final scaledWidth = layout.outputSize.width * pixelRatio;
    final scaledHeight = layout.outputSize.height * pixelRatio;
    if (!scaledWidth.isFinite || !scaledHeight.isFinite) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.text('error.invalidCompositionOutputSize'),
          recoverySuggestion: localizations.text(
            'error.checkBackgroundSettings',
          ),
        ),
      );
    }

    final outputWidth = scaledWidth.round();
    final outputHeight = scaledHeight.round();
    if (outputWidth <= 0 || outputHeight <= 0) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.text('error.invalidCompositionOutputSize'),
          recoverySuggestion: localizations.text(
            'error.checkBackgroundSettings',
          ),
        ),
      );
    }
    if (outputWidth > budget.maxOutputWidth ||
        outputHeight > budget.maxOutputHeight) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.params('error.compositionDimensionsTooLarge', {
            'width': '$outputWidth',
            'height': '$outputHeight',
            'maxWidth': '${budget.maxOutputWidth}',
            'maxHeight': '${budget.maxOutputHeight}',
          }),
          recoverySuggestion: localizations.text('error.reduceCompositionSize'),
        ),
      );
    }

    if (!_isPixelCountWithinLimit(
      width: outputWidth,
      height: outputHeight,
      maxPixels: budget.maxOutputPixels,
    )) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.params('error.compositionPixelsTooLarge', {
            'pixels': '${outputWidth * outputHeight}',
            'limit': '${budget.maxOutputPixels}',
          }),
          recoverySuggestion: localizations.text('error.reduceCompositionSize'),
        ),
      );
    }

    final outputPixels = outputWidth * outputHeight;
    final estimatedMemoryBytes =
        outputPixels * 8 +
        sourceBytes.length +
        (customBackgroundBytes?.length ?? 0) +
        sourceDecodedBytes +
        customBackgroundDecodedBytes;
    if (estimatedMemoryBytes > budget.maxEstimatedMemoryBytes) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.invalidInput,
          message: localizations.params('error.compositionMemoryTooLarge', {
            'bytes': '$estimatedMemoryBytes',
            'limit': '${budget.maxEstimatedMemoryBytes}',
          }),
          recoverySuggestion: localizations.text('error.reduceCompositionSize'),
        ),
      );
    }

    return AppResult.success(
      _OutputBudgetMetrics(
        pixelRatio: pixelRatio,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      ),
    );
  }

  static int _estimatedDecodedImageBytes(ui.Image image) {
    return image.width * image.height * 4;
  }

  static bool _isPixelCountWithinLimit({
    required int width,
    required int height,
    required int maxPixels,
  }) {
    if (width <= 0 || height <= 0 || maxPixels <= 0) return false;
    return width <= maxPixels ~/ height;
  }

  static void _paintBackground(
    Canvas canvas,
    Size size,
    BackgroundState state,
    ui.Image? customBackgroundImage,
  ) {
    switch (state.type) {
      case BackgroundType.none:
        break;
      case BackgroundType.gradient:
        final paint = Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(size.width, size.height),
            state.gradientPreset.colors,
          );
        canvas.drawRect(Offset.zero & size, paint);
        break;
      case BackgroundType.solid:
        canvas.drawRect(Offset.zero & size, Paint()..color = state.solidColor);
        break;
      case BackgroundType.image:
        if (customBackgroundImage == null) {
          ImageBackgroundPlaceholderPainter.paintPlaceholder(canvas, size);
        } else {
          _drawCoverImage(canvas, customBackgroundImage, Offset.zero & size);
        }
        break;
      case BackgroundType.pattern:
        PatternPainter.paintPattern(
          canvas,
          size,
          preset: state.patternPreset,
          color: state.patternColor,
          backgroundColor: state.patternBackgroundColor,
          scale: state.patternScale,
        );
        break;
    }
  }

  static void _paintWindow(
    Canvas canvas,
    BackgroundLayoutMetrics layout,
    BackgroundState state,
    ui.Image sourceImage,
  ) {
    if (state.type != BackgroundType.none) {
      _paintShadow(canvas, layout.windowRect, state);
    }

    if (layout.titleBarRect != null) {
      _paintTitleBar(canvas, layout.titleBarRect!, state);
    }

    canvas.save();
    canvas.clipRRect(_imageRRect(layout.imageRect, state));
    _drawImageToRect(canvas, sourceImage, layout.imageRect);
    canvas.restore();
  }

  static void _paintShadow(Canvas canvas, Rect rect, BackgroundState state) {
    if (state.shadowBlur <= 0) return;

    final paint = Paint()
      ..color = const Color(0x73000000).withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, state.shadowBlur);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(Offset(0, state.shadowOffsetY)),
        Radius.circular(state.cornerRadius),
      ),
      paint,
    );
  }

  static void _paintTitleBar(Canvas canvas, Rect rect, BackgroundState state) {
    final radius = Radius.circular(state.cornerRadius);
    final titleRRect = RRect.fromRectAndCorners(
      rect,
      topLeft: radius,
      topRight: radius,
    );
    canvas.drawRRect(titleRRect, Paint()..color = const Color(0xFFE8E8E8));

    final centerY = rect.center.dy;
    final colors = [
      const Color(0xFFFF5F57),
      const Color(0xFFFEBC2E),
      const Color(0xFF28C840),
    ];
    for (var i = 0; i < colors.length; i += 1) {
      canvas.drawCircle(
        Offset(rect.left + 16 + i * 18, centerY),
        6,
        Paint()..color = colors[i],
      );
    }
  }

  static void _paintAnnotations(
    Canvas canvas,
    BackgroundLayoutMetrics layout,
    Size imageSize,
    BackgroundState state,
    AnnotationPaintCallback paintAnnotations,
  ) {
    final safeImageSize = Size(
      imageSize.width.isFinite && imageSize.width > 0 ? imageSize.width : 1.0,
      imageSize.height.isFinite && imageSize.height > 0
          ? imageSize.height
          : 1.0,
    );
    canvas.save();
    canvas.clipRRect(_imageRRect(layout.imageRect, state));
    canvas.translate(layout.imageRect.left, layout.imageRect.top);
    canvas.scale(
      layout.imageRect.width / safeImageSize.width,
      layout.imageRect.height / safeImageSize.height,
    );
    paintAnnotations(canvas, safeImageSize);
    canvas.restore();
  }

  static void _drawCoverImage(Canvas canvas, ui.Image image, Rect outputRect) {
    _drawFittedImage(canvas, image, outputRect, BoxFit.cover);
  }

  static void _drawImageToRect(Canvas canvas, ui.Image image, Rect outputRect) {
    _drawFittedImage(canvas, image, outputRect, BoxFit.fill);
  }

  static void _drawFittedImage(
    Canvas canvas,
    ui.Image image,
    Rect outputRect,
    BoxFit fit,
  ) {
    final inputSize = Size(image.width.toDouble(), image.height.toDouble());
    final fittedSizes = applyBoxFit(fit, inputSize, outputRect.size);
    final sourceRect = Alignment.center.inscribe(
      fittedSizes.source,
      Offset.zero & inputSize,
    );
    final destinationRect = Alignment.center.inscribe(
      fittedSizes.destination,
      outputRect,
    );

    canvas.drawImageRect(
      image,
      sourceRect,
      destinationRect,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  static RRect _imageRRect(Rect rect, BackgroundState state) {
    final radius = Radius.circular(state.cornerRadius);
    if (state.type == BackgroundType.none) {
      return RRect.fromRectAndRadius(rect, Radius.zero);
    }
    if (state.showTitleBar) {
      return RRect.fromRectAndCorners(
        rect,
        bottomLeft: radius,
        bottomRight: radius,
      );
    }
    return RRect.fromRectAndRadius(rect, radius);
  }
}
