import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class CroppedImageResult {
  final Uint8List imageBytes;
  final Size size;

  const CroppedImageResult({required this.imageBytes, required this.size});
}

class ImageCropUtils {
  const ImageCropUtils._();

  static const int defaultMaxCropPixels = 67108864;
  static const int defaultMaxCropMemoryBytes = 512 * 1024 * 1024;

  static Future<CroppedImageResult?> cropPngBytes({
    required Uint8List imageBytes,
    required Rect selectionRect,
    Size? sourceSize,
    int maxOutputPixels = defaultMaxCropPixels,
    int maxEstimatedMemoryBytes = defaultMaxCropMemoryBytes,
  }) async {
    if (imageBytes.isEmpty ||
        maxOutputPixels <= 0 ||
        maxEstimatedMemoryBytes <= 0) {
      return null;
    }

    ui.Image? image;
    ui.Picture? picture;
    ui.Image? croppedImage;

    try {
      image = await _decodeImage(imageBytes);
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      if (!_isWithinDecodeBudget(
        image: image,
        encodedBytes: imageBytes.length,
        maxEstimatedMemoryBytes: maxEstimatedMemoryBytes,
      )) {
        return null;
      }
      final cropRect = scaleSelectionToImage(
        selectionRect: selectionRect,
        sourceSize: sourceSize ?? imageSize,
        imageSize: imageSize,
      );

      if (cropRect.width < 1 || cropRect.height < 1) {
        return null;
      }

      final outputWidth = cropRect.width.round();
      final outputHeight = cropRect.height.round();
      if (outputWidth <= 0 ||
          outputHeight <= 0 ||
          !_isPixelCountWithinLimit(
            width: outputWidth,
            height: outputHeight,
            maxPixels: maxOutputPixels,
          )) {
        return null;
      }
      if (!_isCropMemoryWithinLimit(
        image: image,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        encodedBytes: imageBytes.length,
        maxEstimatedMemoryBytes: maxEstimatedMemoryBytes,
      )) {
        return null;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final destinationRect = Rect.fromLTWH(
        0,
        0,
        outputWidth.toDouble(),
        outputHeight.toDouble(),
      );

      canvas.drawImageRect(image, cropRect, destinationRect, Paint());

      picture = recorder.endRecording();
      croppedImage = await picture.toImage(outputWidth, outputHeight);
      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) return null;

      return CroppedImageResult(
        imageBytes: bytes,
        size: Size(outputWidth.toDouble(), outputHeight.toDouble()),
      );
    } catch (_) {
      return null;
    } finally {
      croppedImage?.dispose();
      picture?.dispose();
      image?.dispose();
    }
  }

  static Rect scaleSelectionToImage({
    required Rect selectionRect,
    required Size sourceSize,
    required Size imageSize,
  }) {
    if (!_isPositiveFiniteSize(sourceSize) ||
        !_isPositiveFiniteSize(imageSize) ||
        !_isFiniteRect(selectionRect)) {
      return Rect.zero;
    }

    final normalizedRect = Rect.fromLTRB(
      math.min(selectionRect.left, selectionRect.right),
      math.min(selectionRect.top, selectionRect.bottom),
      math.max(selectionRect.left, selectionRect.right),
      math.max(selectionRect.top, selectionRect.bottom),
    );
    final scaleX = imageSize.width / sourceSize.width;
    final scaleY = imageSize.height / sourceSize.height;
    final scaledRect = Rect.fromLTRB(
      normalizedRect.left * scaleX,
      normalizedRect.top * scaleY,
      normalizedRect.right * scaleX,
      normalizedRect.bottom * scaleY,
    );

    final left = _clampDouble(
      scaledRect.left.floorToDouble(),
      0,
      imageSize.width,
    );
    final top = _clampDouble(
      scaledRect.top.floorToDouble(),
      0,
      imageSize.height,
    );
    final right = _clampDouble(
      scaledRect.right.ceilToDouble(),
      0,
      imageSize.width,
    );
    final bottom = _clampDouble(
      scaledRect.bottom.ceilToDouble(),
      0,
      imageSize.height,
    );

    if (right <= left || bottom <= top) {
      return Rect.zero;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Rect scaleRetinaRect(Rect rect, double devicePixelRatio) {
    if (!_isFiniteRect(rect)) return Rect.zero;
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) return rect;
    return Rect.fromLTRB(
      rect.left / devicePixelRatio,
      rect.top / devicePixelRatio,
      rect.right / devicePixelRatio,
      rect.bottom / devicePixelRatio,
    );
  }

  static Size scaleRetinaSize(Size size, double devicePixelRatio) {
    if (!_isFiniteSize(size)) return Size.zero;
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) return size;
    return Size(size.width / devicePixelRatio, size.height / devicePixelRatio);
  }

  static Future<ui.Image> _decodeImage(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec?.dispose();
    }
  }

  static double _clampDouble(double value, double min, double max) {
    return math.max(min, math.min(value, max));
  }

  static bool _isWithinDecodeBudget({
    required ui.Image image,
    required int encodedBytes,
    required int maxEstimatedMemoryBytes,
  }) {
    final decodedBytes = image.width * image.height * 4;
    return decodedBytes + encodedBytes <= maxEstimatedMemoryBytes;
  }

  static bool _isPixelCountWithinLimit({
    required int width,
    required int height,
    required int maxPixels,
  }) {
    if (width <= 0 || height <= 0 || maxPixels <= 0) return false;
    return width <= maxPixels ~/ height;
  }

  static bool _isCropMemoryWithinLimit({
    required ui.Image image,
    required int outputWidth,
    required int outputHeight,
    required int encodedBytes,
    required int maxEstimatedMemoryBytes,
  }) {
    if (!_isPixelCountWithinLimit(
      width: outputWidth,
      height: outputHeight,
      maxPixels: maxEstimatedMemoryBytes ~/ 8,
    )) {
      return false;
    }
    final sourceDecodedBytes = image.width * image.height * 4;
    final outputBytes = outputWidth * outputHeight * 8;
    return sourceDecodedBytes + outputBytes + encodedBytes <=
        maxEstimatedMemoryBytes;
  }

  static bool _isFiniteRect(Rect rect) {
    return rect.left.isFinite &&
        rect.top.isFinite &&
        rect.right.isFinite &&
        rect.bottom.isFinite;
  }

  static bool _isFiniteSize(Size size) {
    return size.width.isFinite && size.height.isFinite;
  }

  static bool _isPositiveFiniteSize(Size size) {
    return _isFiniteSize(size) && size.width > 0 && size.height > 0;
  }
}
