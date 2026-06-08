import 'dart:convert';
import 'dart:typed_data';

import 'sticker_asset.dart';
import 'sticker_pack.dart';

class StickerAssetImportPolicy {
  static const int maxSvgBytes = 256 * 1024;
  static const int maxPngBytes = 4 * 1024 * 1024;
  static const int maxPackBytes = 16 * 1024 * 1024;
  static const int maxPackFileBytes = 24 * 1024 * 1024;
  static const int maxPackStickers = 256;
  static const int maxImageDimension = 4096;
  static const int maxImagePixels = 16 * 1000 * 1000;
  static const int maxSvgElements = 512;

  static const Set<String> allowedSvgTags = {
    'svg',
    'g',
    'defs',
    'title',
    'desc',
    'path',
    'line',
    'rect',
    'circle',
    'ellipse',
    'polygon',
    'polyline',
    'text',
    'tspan',
    'lineargradient',
    'radialgradient',
    'stop',
  };

  static const Set<String> blockedSvgAttributes = {'href', 'xlink:href', 'src'};

  const StickerAssetImportPolicy._();
}

class StickerAssetValidation {
  static final RegExp _svgTagPattern = RegExp(
    r'<\s*/?\s*([A-Za-z][A-Za-z0-9:_-]*)\b',
  );
  static final RegExp _svgAttributePattern = RegExp(
    r'''([A-Za-z_:][A-Za-z0-9:._-]*)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''',
  );
  static final RegExp _externalReferencePattern = RegExp(
    r'(https?:|file:|data:|//)',
    caseSensitive: false,
  );
  static final RegExp _svgStyleReferencePattern = RegExp(
    r'(@import|expression\s*\()',
    caseSensitive: false,
  );
  static final RegExp _svgUrlReferencePattern = RegExp(
    r'''url\s*\(\s*['"]?\s*([^'")\s]+)''',
    caseSensitive: false,
  );
  static final RegExp _svgRootPattern = RegExp(
    r'^(<\?xml[^>]*>\s*)?(<!--.*?-->\s*)*<svg\b',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _unsafeSvgMarkupPattern = RegExp(
    r'<!\s*(doctype|entity)|<\?\s*xml-stylesheet\b',
    caseSensitive: false,
  );

  const StickerAssetValidation._();

  static void validateFile({
    required String filePath,
    required StickerAssetFormat format,
    required Uint8List bytes,
    String? svgContent,
  }) {
    if (format == StickerAssetFormat.svg) {
      validateSvg(svgContent ?? utf8.decode(bytes), source: filePath);
      return;
    }
    validatePng(bytes, source: filePath);
  }

  static void validateAsset(StickerAsset sticker, {String? source}) {
    if (sticker.format == StickerAssetFormat.svg) {
      final svg = sticker.svgContent;
      if (svg != null && svg.isNotEmpty) {
        validateSvg(svg, source: source ?? sticker.name);
      }
      return;
    }

    final dataBase64 = sticker.dataBase64;
    if (dataBase64 != null && dataBase64.isNotEmpty) {
      validatePng(
        _decodeBase64(dataBase64, source ?? sticker.name),
        source: source ?? sticker.name,
      );
    }
  }

  static void validatePack(StickerPack pack, {String? source}) {
    if (pack.stickers.length > StickerAssetImportPolicy.maxPackStickers) {
      throw FormatException('Sticker pack contains too many stickers.', source);
    }

    final stickerIds = <String>{};
    var totalBytes = 0;
    for (final sticker in pack.stickers) {
      if (sticker.id.trim().isEmpty) {
        throw FormatException('Sticker pack contains an empty id.', source);
      }
      if (!stickerIds.add(sticker.id)) {
        throw FormatException(
          'Sticker pack contains duplicate sticker ids.',
          source,
        );
      }
      if (!_hasInlineResource(sticker)) {
        throw FormatException('Sticker pack resources must be inline.', source);
      }
      validateAsset(sticker, source: '${source ?? pack.name}/${sticker.name}');
      totalBytes += _inlineByteSize(sticker);
      if (totalBytes > StickerAssetImportPolicy.maxPackBytes) {
        throw FormatException('Sticker pack is too large.', source);
      }
    }
  }

  static bool _hasInlineResource(StickerAsset sticker) {
    if (sticker.format == StickerAssetFormat.svg) {
      return sticker.svgContent != null && sticker.svgContent!.isNotEmpty;
    }
    return sticker.dataBase64 != null && sticker.dataBase64!.isNotEmpty;
  }

  static void validateSvg(String svg, {String? source}) {
    final bytes = utf8.encode(svg);
    if (bytes.isEmpty) {
      throw FormatException('Sticker SVG is empty.', source);
    }
    if (bytes.length > StickerAssetImportPolicy.maxSvgBytes) {
      throw FormatException('Sticker SVG is too large.', source);
    }
    if (!_svgRootPattern.hasMatch(svg.trimLeft())) {
      throw FormatException(
        'Sticker SVG must start with an svg element.',
        source,
      );
    }
    if (_unsafeSvgMarkupPattern.hasMatch(svg)) {
      throw FormatException('Sticker SVG contains unsafe markup.', source);
    }
    if (_svgStyleReferencePattern.hasMatch(svg)) {
      throw FormatException(
        'Sticker SVG contains external references.',
        source,
      );
    }

    var elementCount = 0;
    for (final match in _svgTagPattern.allMatches(svg)) {
      elementCount++;
      if (elementCount > StickerAssetImportPolicy.maxSvgElements) {
        throw FormatException(
          'Sticker SVG contains too many elements.',
          source,
        );
      }

      final tag = match.group(1)?.toLowerCase();
      if (tag == null ||
          !StickerAssetImportPolicy.allowedSvgTags.contains(tag)) {
        throw FormatException(
          'Sticker SVG contains an unsupported tag.',
          source,
        );
      }
    }
    if (elementCount == 0) {
      throw FormatException('Sticker SVG has no elements.', source);
    }

    for (final match in _svgAttributePattern.allMatches(svg)) {
      final attribute = match.group(1)?.toLowerCase();
      if (attribute == null) continue;
      final value = match.group(3) ?? match.group(4) ?? match.group(5) ?? '';
      if (attribute.startsWith('on') ||
          StickerAssetImportPolicy.blockedSvgAttributes.contains(attribute)) {
        throw FormatException(
          'Sticker SVG contains an unsafe attribute.',
          source,
        );
      }
      if (_hasUnsafeAttributeReference(attribute, value)) {
        throw FormatException(
          'Sticker SVG contains external references.',
          source,
        );
      }
    }
  }

  static bool _hasUnsafeAttributeReference(String attribute, String value) {
    if (attribute == 'xmlns' || attribute.startsWith('xmlns:')) {
      return false;
    }
    if (_externalReferencePattern.hasMatch(value)) {
      return true;
    }
    for (final match in _svgUrlReferencePattern.allMatches(value)) {
      final reference = match.group(1)?.trim() ?? '';
      if (reference.isNotEmpty && !reference.startsWith('#')) {
        return true;
      }
    }
    return false;
  }

  static void validatePng(Uint8List bytes, {String? source}) {
    if (bytes.isEmpty) {
      throw FormatException('Sticker PNG is empty.', source);
    }
    if (bytes.length > StickerAssetImportPolicy.maxPngBytes) {
      throw FormatException('Sticker PNG is too large.', source);
    }
    final size = _readPngSize(bytes, source: source);
    if (size.width <= 0 || size.height <= 0) {
      throw FormatException('Sticker PNG dimensions are invalid.', source);
    }
    if (size.width > StickerAssetImportPolicy.maxImageDimension ||
        size.height > StickerAssetImportPolicy.maxImageDimension ||
        size.width * size.height > StickerAssetImportPolicy.maxImagePixels) {
      throw FormatException('Sticker PNG dimensions are too large.', source);
    }
  }

  static _PngSize _readPngSize(Uint8List bytes, {String? source}) {
    const pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    const ihdrType = [0x49, 0x48, 0x44, 0x52];
    if (bytes.length < 33) {
      throw FormatException('Sticker PNG header is invalid.', source);
    }
    for (var index = 0; index < pngHeader.length; index++) {
      if (bytes[index] != pngHeader[index]) {
        throw FormatException('Sticker PNG header is invalid.', source);
      }
    }
    if (_readUint32(bytes, 8) != 13) {
      throw FormatException('Sticker PNG header is invalid.', source);
    }
    for (var index = 0; index < ihdrType.length; index++) {
      if (bytes[12 + index] != ihdrType[index]) {
        throw FormatException('Sticker PNG header is invalid.', source);
      }
    }
    final bitDepth = bytes[24];
    final colorType = bytes[25];
    final compression = bytes[26];
    final filter = bytes[27];
    final interlace = bytes[28];
    final validBitDepth = switch (colorType) {
      0 => const {1, 2, 4, 8, 16}.contains(bitDepth),
      2 => const {8, 16}.contains(bitDepth),
      3 => const {1, 2, 4, 8}.contains(bitDepth),
      4 => const {8, 16}.contains(bitDepth),
      6 => const {8, 16}.contains(bitDepth),
      _ => false,
    };
    if (!validBitDepth ||
        compression != 0 ||
        filter != 0 ||
        (interlace != 0 && interlace != 1)) {
      throw FormatException('Sticker PNG header is invalid.', source);
    }
    return _PngSize(_readUint32(bytes, 16), _readUint32(bytes, 20));
  }

  static int _readUint32(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static Uint8List _decodeBase64(String value, String source) {
    try {
      return base64Decode(value);
    } on FormatException catch (error) {
      throw FormatException(
        'Sticker PNG base64 is invalid.',
        source,
        error.offset,
      );
    }
  }

  static int _inlineByteSize(StickerAsset sticker) {
    final svg = sticker.svgContent;
    if (svg != null && svg.isNotEmpty) return utf8.encode(svg).length;
    final dataBase64 = sticker.dataBase64;
    if (dataBase64 != null && dataBase64.isNotEmpty) {
      return _decodeBase64(dataBase64, sticker.name).length;
    }
    return 0;
  }
}

class _PngSize {
  final int width;
  final int height;

  const _PngSize(this.width, this.height);
}
