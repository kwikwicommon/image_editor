import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart';

void main() {
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

  test('SVG validation accepts safe SVG and rejects external references', () {
    expect(
      () => StickerAssetValidation.validateSvg(
        '<svg viewBox="0 0 1 1"><path d="M0 0 L1 1"/></svg>',
      ),
      returnsNormally,
    );
    expect(
      () => StickerAssetValidation.validateSvg(
        '<svg><image href="https://example.com/a.png"/></svg>',
      ),
      throwsFormatException,
    );
  });

  test('PNG validation checks header and dimensions', () {
    final bytes = Uint8List.fromList(base64Decode(pngBase64));

    expect(() => StickerAssetValidation.validatePng(bytes), returnsNormally);
    expect(
      () => StickerAssetValidation.validatePng(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test('sticker pack validation requires inline resources', () {
    final pack = StickerPack(
      name: 'Inline',
      stickers: const [
        StickerAsset(
          id: 'safe',
          name: 'Safe',
          category: StickerCategory.custom,
          svgContent: '<svg viewBox="0 0 1 1"></svg>',
        ),
      ],
    );

    expect(() => StickerAssetValidation.validatePack(pack), returnsNormally);
    expect(
      () => StickerAssetValidation.validatePack(
        const StickerPack(
          name: 'Referenced',
          stickers: [
            StickerAsset(
              id: 'ref',
              name: 'Ref',
              category: StickerCategory.custom,
              assetPath: 'ref.svg',
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
  });
}
