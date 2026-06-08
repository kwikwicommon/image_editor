import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../canvas/annotation_element.dart';

class StickerRenderData {
  final PictureInfo? pictureInfo;
  final ui.Image? image;

  const StickerRenderData({this.pictureInfo, this.image});
}

class StickerRenderCache extends ChangeNotifier {
  final Map<String, PictureInfo> _svgCache = {};
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Future<void>> _pendingLoads = {};
  final Set<String> _failedKeys = {};
  var _generation = 0;
  var _isDisposed = false;

  StickerRenderData? renderFor(StickerElement element) {
    final key = _cacheKey(element);
    if (element.format == StickerFormat.svg) {
      final pictureInfo = _svgCache[key];
      if (pictureInfo != null) {
        return StickerRenderData(pictureInfo: pictureInfo);
      }
    } else {
      final image = _imageCache[key];
      if (image != null) {
        return StickerRenderData(image: image);
      }
    }
    _ensureLoaded(element, key);
    return null;
  }

  Future<void> preloadAll(Iterable<AnnotationElement> elements) {
    return Future.wait(elements.whereType<StickerElement>().map(preload));
  }

  Future<void> preload(StickerElement element) {
    final key = _cacheKey(element);
    if (_isCached(element, key) || _failedKeys.contains(key)) {
      return Future<void>.value();
    }
    return _ensureLoaded(element, key);
  }

  void clear() {
    _clearCaches(notify: true);
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _clearCaches(notify: false);
    super.dispose();
  }

  void _clearCaches({required bool notify}) {
    _generation += 1;
    for (final pictureInfo in _svgCache.values) {
      pictureInfo.picture.dispose();
    }
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _svgCache.clear();
    _imageCache.clear();
    _pendingLoads.clear();
    _failedKeys.clear();
    if (notify && !_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _ensureLoaded(StickerElement element, String key) {
    if (_isDisposed) {
      return Future<void>.value();
    }
    if (_pendingLoads.containsKey(key)) {
      return _pendingLoads[key]!;
    }
    if (_failedKeys.contains(key) || _isCached(element, key)) {
      return Future<void>.value();
    }

    final generation = _generation;
    late final Future<void> load;
    load = _load(element)
        .then((renderData) {
          if (_isDisposed || generation != _generation) {
            _disposeRenderData(renderData);
            return;
          }
          final pictureInfo = renderData?.pictureInfo;
          final image = renderData?.image;
          if (pictureInfo != null) {
            _svgCache[key] = pictureInfo;
          } else if (image != null) {
            _imageCache[key] = image;
          }
        })
        .catchError((Object error) {
          if (!_isDisposed && generation == _generation) {
            _failedKeys.add(key);
          }
        })
        .whenComplete(() {
          if (_pendingLoads[key] == load) {
            _pendingLoads.remove(key);
            if (!_isDisposed) {
              notifyListeners();
            }
          }
        });
    _pendingLoads[key] = load;
    return load;
  }

  bool _isCached(StickerElement element, String key) {
    return element.format == StickerFormat.svg
        ? _svgCache.containsKey(key)
        : _imageCache.containsKey(key);
  }

  Future<StickerRenderData?> _load(StickerElement element) async {
    if (element.format == StickerFormat.svg) {
      final svg = await _resolveSvg(element);
      if (svg == null || svg.trim().isEmpty) return null;
      final currentColor = element.isRecolorable
          ? (element.tintColor ?? Colors.black)
          : Colors.black;
      final loader = SvgStringLoader(
        svg,
        theme: SvgTheme(currentColor: currentColor),
      );
      return StickerRenderData(pictureInfo: await vg.loadPicture(loader, null));
    }

    final bytes = await _resolveImageBytes(element);
    if (bytes == null || bytes.isEmpty) return null;
    return StickerRenderData(image: await _decodeImage(bytes));
  }

  Future<String?> _resolveSvg(StickerElement element) async {
    final svgContent = element.svgContent;
    if (svgContent != null) {
      if (utf8.encode(svgContent).length > _StickerRenderLimits.maxSvgBytes) {
        return null;
      }
      return svgContent;
    }
    if (element.assetPath.isEmpty) return null;
    final file = File(element.assetPath);
    if (!await file.exists()) return null;
    if (await file.length() > _StickerRenderLimits.maxSvgBytes) return null;
    return file.readAsString();
  }

  Future<Uint8List?> _resolveImageBytes(StickerElement element) async {
    if (element.dataBase64 != null) {
      final byteLength = _decodedBase64Length(element.dataBase64!);
      if (byteLength > _StickerRenderLimits.maxPngBytes) return null;
      return base64Decode(element.dataBase64!);
    }
    if (element.assetPath.isEmpty) return null;
    final file = File(element.assetPath);
    if (!await file.exists()) return null;
    if (await file.length() > _StickerRenderLimits.maxPngBytes) return null;
    return file.readAsBytes();
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec?.dispose();
    }
  }

  void _disposeRenderData(StickerRenderData? renderData) {
    renderData?.pictureInfo?.picture.dispose();
    renderData?.image?.dispose();
  }

  String _cacheKey(StickerElement element) {
    final colorValue = element.isRecolorable
        ? (element.tintColor ?? Colors.black).toARGB32()
        : 0;
    return [
      element.format.name,
      element.resourceId ?? '',
      element.resourceHash ?? '',
      element.assetPath,
      element.svgContent?.hashCode ?? 0,
      element.dataBase64?.hashCode ?? 0,
      colorValue,
    ].join('|');
  }

  int _decodedBase64Length(String value) {
    final sanitized = value.replaceAll(RegExp(r'\s'), '');
    if (sanitized.isEmpty) return 0;
    final padding = sanitized.endsWith('==')
        ? 2
        : sanitized.endsWith('=')
        ? 1
        : 0;
    return (sanitized.length * 3 ~/ 4) - padding;
  }
}

class _StickerRenderLimits {
  static const int maxSvgBytes = 256 * 1024;
  static const int maxPngBytes = 4 * 1024 * 1024;

  const _StickerRenderLimits._();
}
