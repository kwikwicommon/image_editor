
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'image_editor_platform.dart';
import 'types.dart';

const List<int> _pngSignature = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];
const int _pngHeaderByteCount = 33;
const int _ihdrChunkLength = 13;
const int _maxClipboardPngBytes = 128 * 1024 * 1024;
const int _maxClipboardDecodedBytes = 256 * 1024 * 1024;
const int _clipboardBytesPerPixel = 4;

class MethodChannelImageEditor extends ImageEditorPlatform {
  MethodChannelImageEditor({MethodChannel? methodChannel})
    : methodChannel =
          methodChannel ?? const MethodChannel('image_editor/native');

  @visibleForTesting
  final MethodChannel methodChannel;

  @override
  Future<ImageEditorCapabilities> queryCapabilities() async {
    try {
      final rawValue = await methodChannel.invokeMethod<Object?>(
        'editor.queryCapabilities',
      );
      return ImageEditorCapabilities.fromNative(rawValue);
    } on MissingPluginException {
      return ImageEditorCapabilities.unsupported;
    } on PlatformException catch (error) {
      return ImageEditorCapabilities(
        platform: 'unsupported',
        canCopyPngToClipboard: false,
        extra: Map<String, Object?>.unmodifiable(<String, Object?>{
          'errorCode': error.code,
          if (error.message != null) 'errorMessage': error.message,
          if (error.details != null) 'errorDetails': error.details,
        }),
      );
    }
  }

  @override
  Future<ImageEditorClipboardResult> copyPngToClipboard(
    Uint8List pngBytes,
  ) async {
    final validationFailure = _validateClipboardPng(pngBytes);
    if (validationFailure != null) {
      return validationFailure;
    }

    try {
      final rawValue = await methodChannel.invokeMethod<Object?>(
        'editor.copyPngToClipboard',
        <String, Object?>{'pngBytes': pngBytes},
      );
      return ImageEditorClipboardResult.fromNative(rawValue);
    } on MissingPluginException {
      return const ImageEditorClipboardResult.failure(
        code: 'unsupported',
        message: 'Native clipboard copy is not available on this platform.',
      );
    } on PlatformException catch (error) {
      return ImageEditorClipboardResult.failure(
        code: error.code,
        message: error.message ?? 'Native clipboard copy failed.',
        details: error.details,
      );
    }
  }
}

ImageEditorClipboardResult? _validateClipboardPng(Uint8List pngBytes) {
  if (pngBytes.isEmpty) {
    return const ImageEditorClipboardResult.failure(
      code: 'invalidInput',
      message: 'PNG bytes are required.',
    );
  }
  if (pngBytes.length > _maxClipboardPngBytes) {
    return const ImageEditorClipboardResult.failure(
      code: 'tooLarge',
      message: 'The PNG image is too large for clipboard copy.',
      recoverySuggestion: 'Export or save the image manually and try again.',
    );
  }
  if (!_hasPngSignature(pngBytes)) {
    return const ImageEditorClipboardResult.failure(
      code: 'invalidInput',
      message: 'A PNG image is required for clipboard copy.',
      recoverySuggestion: 'Create a valid PNG image and try again.',
    );
  }

  final header = _readPngHeader(pngBytes);
  if (header == null) {
    return const ImageEditorClipboardResult.failure(
      code: 'invalidInput',
      message: 'The PNG header is invalid for clipboard copy.',
      recoverySuggestion: 'Create a valid PNG image and try again.',
    );
  }

  final maxClipboardPixels =
      _maxClipboardDecodedBytes ~/ _clipboardBytesPerPixel;
  if (header.width > maxClipboardPixels ~/ header.height) {
    return ImageEditorClipboardResult.failure(
      code: 'tooLarge',
      message: 'The PNG dimensions are too large for clipboard copy.',
      recoverySuggestion: 'Export or save the image manually and try again.',
      details: Map<String, Object?>.unmodifiable(<String, Object?>{
        'width': header.width,
        'height': header.height,
        'maxDecodedBytes': _maxClipboardDecodedBytes,
      }),
    );
  }

  return null;
}

bool _hasPngSignature(Uint8List bytes) {
  if (bytes.length < _pngSignature.length) {
    return false;
  }
  for (var index = 0; index < _pngSignature.length; index += 1) {
    if (bytes[index] != _pngSignature[index]) {
      return false;
    }
  }
  return true;
}

_PngHeader? _readPngHeader(Uint8List bytes) {
  if (bytes.length < _pngHeaderByteCount) {
    return null;
  }

  final byteData = ByteData.sublistView(bytes);
  final ihdrLength = byteData.getUint32(8, Endian.big);
  if (ihdrLength != _ihdrChunkLength ||
      bytes[12] != 0x49 ||
      bytes[13] != 0x48 ||
      bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    return null;
  }

  final width = byteData.getUint32(16, Endian.big);
  final height = byteData.getUint32(20, Endian.big);
  if (width == 0 || height == 0) {
    return null;
  }

  return _PngHeader(width: width, height: height);
}

class _PngHeader {
  const _PngHeader({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}
