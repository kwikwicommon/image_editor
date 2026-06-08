import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/app_result.dart';
import '../core/image_editor_localizations.dart';

enum ImageExportFormat { png, jpeg, webp }

class EncodedImage {
  final Uint8List imageBytes;
  final ImageExportFormat format;
  final String extension;
  final String mimeType;

  const EncodedImage({
    required this.imageBytes,
    required this.format,
    required this.extension,
    required this.mimeType,
  });
}

abstract class ImageEncoderPlatform {
  const ImageEncoderPlatform();

  Future<AppResult<EncodedImage>> encode({
    required Uint8List imageBytes,
    required ImageExportFormat format,
    required int quality,
  });
}

class ImageEncoder {
  final ImageEncoderPlatform? platform;
  final ImageEditorLocalizations localizations;

  const ImageEncoder({
    this.platform,
    this.localizations = const DefaultImageEditorLocalizations(),
  });

  Future<AppResult<EncodedImage>> encode({
    required Uint8List imageBytes,
    required ImageExportFormat format,
    int quality = 90,
  }) async {
    final AppResult<EncodedImage>? fallbackFailure;
    if (format == ImageExportFormat.png) {
      final pngResult = await _encodePngFallback(imageBytes);
      if (pngResult.isSuccess) return pngResult;
      fallbackFailure = pngResult;
    } else {
      fallbackFailure = null;
    }

    final encoderPlatform = platform;
    if (encoderPlatform == null) {
      if (fallbackFailure != null) return fallbackFailure;
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.unsupported,
          message: localizations.text('error.unsupportedEncodingFormat'),
          recoverySuggestion: localizations.text('error.tryAgain'),
        ),
      );
    }

    final AppResult<EncodedImage> result;
    try {
      result = await encoderPlatform.encode(
        imageBytes: imageBytes,
        format: format,
        quality: _clampQuality(quality),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.platform,
          message: localizations.text('error.compositedImageEncodeFailed'),
          recoverySuggestion: localizations.text('error.tryAgain'),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    if (result.isFailure) return result;
    final encoded = result.requireValue;
    if (encoded.imageBytes.isEmpty) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.ioFailure,
          message: localizations.text('error.encodedImageEmpty'),
          recoverySuggestion: localizations.text('error.tryAgain'),
        ),
      );
    }
    return AppResult.success(
      EncodedImage(
        imageBytes: encoded.imageBytes,
        format: format,
        extension: extensionForFormat(format),
        mimeType: mimeTypeForFormat(format),
      ),
    );
  }

  Future<AppResult<EncodedImage>> _encodePngFallback(
    Uint8List imageBytes,
  ) async {
    if (_hasCompletePngContainer(imageBytes)) {
      return AppResult.success(
        EncodedImage(
          imageBytes: Uint8List.fromList(imageBytes),
          format: ImageExportFormat.png,
          extension: extensionForFormat(ImageExportFormat.png),
          mimeType: mimeTypeForFormat(ImageExportFormat.png),
        ),
      );
    }

    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        return AppResult.failure(
          AppFailure(
            code: AppFailureCode.serialization,
            message: localizations.text('error.encodedImageEmpty'),
            recoverySuggestion: localizations.text('error.tryAgain'),
          ),
        );
      }
      return AppResult.success(
        EncodedImage(
          imageBytes: bytes,
          format: ImageExportFormat.png,
          extension: extensionForFormat(ImageExportFormat.png),
          mimeType: mimeTypeForFormat(ImageExportFormat.png),
        ),
      );
    } catch (error, stackTrace) {
      return AppResult.failure(
        AppFailure(
          code: AppFailureCode.serialization,
          message: localizations.text('error.compositedImageEncodeFailed'),
          recoverySuggestion: localizations.text('error.tryAgain'),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static String extensionForFormat(ImageExportFormat format) {
    switch (format) {
      case ImageExportFormat.png:
        return 'png';
      case ImageExportFormat.jpeg:
        return 'jpeg';
      case ImageExportFormat.webp:
        return 'webp';
    }
  }

  static String mimeTypeForFormat(ImageExportFormat format) {
    switch (format) {
      case ImageExportFormat.png:
        return 'image/png';
      case ImageExportFormat.jpeg:
        return 'image/jpeg';
      case ImageExportFormat.webp:
        return 'image/webp';
    }
  }

  static int _clampQuality(int value) {
    if (value < 1) return 1;
    if (value > 100) return 100;
    return value;
  }

  static bool _hasPngSignature(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index += 1) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  static bool _hasCompletePngContainer(Uint8List bytes) {
    if (!_hasPngSignature(bytes)) return false;

    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final chunkLength = _readUint32BigEndian(bytes, offset);
      final typeOffset = offset + 4;
      final dataOffset = offset + 8;
      final crcOffset = dataOffset + chunkLength;
      final nextOffset = crcOffset + 4;
      if (chunkLength < 0 || nextOffset > bytes.length) {
        return false;
      }
      if (_isIendChunk(bytes, typeOffset)) {
        return nextOffset == bytes.length;
      }
      offset = nextOffset;
    }

    return false;
  }

  static bool _isIendChunk(Uint8List bytes, int offset) {
    return bytes[offset] == 73 &&
        bytes[offset + 1] == 69 &&
        bytes[offset + 2] == 78 &&
        bytes[offset + 3] == 68;
  }

  static int _readUint32BigEndian(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
