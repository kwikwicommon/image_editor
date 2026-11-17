import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../src/core/image_editor_localizations.dart';
import '../src/stickers/sticker_asset.dart';
import '../src/stickers/sticker_library.dart';

class StickerPanel extends StatelessWidget {
  final StickerLibraryController controller;
  final ValueChanged<StickerAsset> onStickerInserted;
  final ImageEditorLocalizations localizations;

  const StickerPanel({
    super.key,
    required this.controller,
    required this.onStickerInserted,
    this.localizations = const DefaultImageEditorLocalizations(),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: localizations.text('common.search'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: controller.setSearchQuery,
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final category in StickerCategory.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: IconButton(
                            tooltip: localizations.text(category.labelKey),
                            isSelected:
                                controller.selectedCategory.value == category,
                            icon: Icon(category.icon),
                            onPressed: () =>
                                controller.selectCategory(category),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final stickers = controller.filteredStickers;
                  if (stickers.isEmpty) {
                    return Center(
                      child: Text(localizations.text('stickers.noResults')),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: stickers.length,
                    itemBuilder: (context, index) {
                      final sticker = stickers[index];
                      final isFavorite = controller.favoriteIds.contains(
                        sticker.id,
                      );
                      return _StickerTile(
                        sticker: sticker,
                        isFavorite: isFavorite,
                        localizations: localizations,
                        onFavorite: () {
                          unawaited(
                            controller
                                .toggleFavorite(sticker.id)
                                .catchError((Object _) {}),
                          );
                        },
                        onInsert: () {
                          unawaited(
                            controller
                                .addRecent(sticker.id)
                                .catchError((Object _) {}),
                          );
                          onStickerInserted(sticker);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  final StickerAsset sticker;
  final bool isFavorite;
  final ImageEditorLocalizations localizations;
  final VoidCallback onFavorite;
  final VoidCallback onInsert;

  const _StickerTile({
    required this.sticker,
    required this.isFavorite,
    required this.localizations,
    required this.onFavorite,
    required this.onInsert,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stickerName = _localizedStickerName();
    return Tooltip(
      message: stickerName,
      child: InkWell(
        onDoubleTap: onInsert,
        onTap: onInsert,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _StickerPreview(sticker: sticker, label: stickerName),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: localizations.text('common.favorite'),
                  iconSize: 18,
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  ),
                  onPressed: onFavorite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizedStickerName() {
    final key = 'sticker.${sticker.id}';
    final value = localizations.text(key);
    return value == key ? sticker.name : value;
  }
}

class _StickerPreview extends StatelessWidget {
  final StickerAsset sticker;
  final String label;
  static final Map<String, Uint8List> _imageBytesCache = {};

  const _StickerPreview({required this.sticker, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final svgContent = sticker.svgContent;
    if (sticker.format == StickerAssetFormat.svg &&
        svgContent != null &&
        svgContent.trim().isNotEmpty) {
      return SvgPicture.string(
        svgContent,
        fit: BoxFit.contain,
        semanticsLabel: label,
        theme: SvgTheme(
          currentColor: sticker.isRecolorable
              ? colorScheme.primary
              : colorScheme.onSurface,
        ),
        errorBuilder: (context, error, stackTrace) {
          return _StickerFallback(label: label);
        },
      );
    }

    final imageBytes = _decodeImageBytes(
      sticker.dataBase64,
      cacheKey: sticker.resourceId ?? sticker.resourceHash ?? sticker.id,
    );
    if (sticker.format == StickerAssetFormat.png && imageBytes != null) {
      return Image.memory(
        imageBytes,
        fit: BoxFit.contain,
        semanticLabel: label,
        errorBuilder: (context, error, stackTrace) {
          return _StickerFallback(label: label);
        },
      );
    }

    return _StickerFallback(label: label);
  }

  Uint8List? _decodeImageBytes(String? dataBase64, {required String cacheKey}) {
    if (dataBase64 == null || dataBase64.isEmpty) return null;
    final cached = _imageBytesCache[cacheKey];
    if (cached != null) return cached;
    if (_decodedBase64Length(dataBase64) > _StickerPreviewLimits.maxPngBytes) {
      return null;
    }
    try {
      final bytes = base64Decode(dataBase64);
      if (bytes.length > _StickerPreviewLimits.maxPngBytes) return null;
      if (_imageBytesCache.length >= _StickerPreviewLimits.maxCachedImages) {
        _imageBytesCache.remove(_imageBytesCache.keys.first);
      }
      _imageBytesCache[cacheKey] = bytes;
      return bytes;
    } on FormatException {
      return null;
    }
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

class _StickerPreviewLimits {
  static const int maxPngBytes = 4 * 1024 * 1024;
  static const int maxCachedImages = 32;

  const _StickerPreviewLimits._();
}

class _StickerFallback extends StatelessWidget {
  final String label;

  const _StickerFallback({required this.label});

  @override
  Widget build(BuildContext context) {
    final text = label.isEmpty ? '?' : String.fromCharCode(label.runes.first);
    return Center(
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
