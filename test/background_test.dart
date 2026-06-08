import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart';

class ThrowingImageEncoderPlatform extends ImageEncoderPlatform {
  const ThrowingImageEncoderPlatform();

  @override
  Future<AppResult<EncodedImage>> encode({
    required Uint8List imageBytes,
    required ImageExportFormat format,
    required int quality,
  }) {
    throw StateError('native encoder failed');
  }
}

void main() {
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

  test('BackgroundLayoutResolver calculates padded output size', () {
    final metrics = BackgroundLayoutResolver.resolve(
      imageSize: const Size(100, 50),
      backgroundState: const BackgroundState(
        type: BackgroundType.solid,
        padding: 10,
      ),
    );

    expect(metrics.outputSize, const Size(120, 70));
    expect(metrics.imageRect.size, const Size(100, 50));
  });

  test('BackgroundLayoutResolver sanitizes non-finite image sizes', () {
    final metrics = BackgroundLayoutResolver.resolve(
      imageSize: const Size(double.nan, double.infinity),
      backgroundState: const BackgroundState(type: BackgroundType.solid),
    );

    expect(metrics.outputSize.width.isFinite, isTrue);
    expect(metrics.outputSize.height.isFinite, isTrue);
    expect(metrics.imageRect.size, const Size(1, 1));
  });

  test('ImageCropUtils rejects non-finite geometry', () {
    final rect = ImageCropUtils.scaleSelectionToImage(
      selectionRect: Rect.fromLTRB(0, 0, double.nan, 10),
      sourceSize: const Size(100, 100),
      imageSize: const Size(100, 100),
    );

    expect(rect, Rect.zero);
  });

  test('BackgroundComposer rejects excessive pixel ratio', () async {
    final result = await BackgroundComposer.compose(
      imageBytes: Uint8List.fromList(base64Decode(pngBase64)),
      imageSize: const Size(1, 1),
      backgroundState: const BackgroundState(),
      pixelRatio: 99,
      paintAnnotations: (canvas, size) {},
    );

    expect(result.isFailure, isTrue);
    expect(result.requireFailure.code, AppFailureCode.invalidInput);
  });

  test('ImageEncoder wraps platform exceptions as failures', () async {
    const encoder = ImageEncoder(platform: ThrowingImageEncoderPlatform());

    final result = await encoder.encode(
      imageBytes: Uint8List.fromList([1, 2, 3]),
      format: ImageExportFormat.jpeg,
    );

    expect(result.isFailure, isTrue);
    expect(result.requireFailure.code, AppFailureCode.platform);
  });
}
