import 'sticker_asset.dart';

class StickerPack {
  final String name;
  final String version;
  final String author;
  final String resourceMode;
  final List<StickerAsset> stickers;

  const StickerPack({
    required this.name,
    this.version = '1.0',
    this.author = '',
    this.resourceMode = 'inline',
    this.stickers = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version,
    'author': author,
    'resourceMode': resourceMode,
    'stickers': stickers.map((sticker) => sticker.toJson()).toList(),
  };

  factory StickerPack.fromJson(Map<String, dynamic> json) {
    return StickerPack(
      name: json['name'] as String,
      version: json['version'] as String? ?? '1.0',
      author: json['author'] as String? ?? '',
      resourceMode: json['resourceMode'] as String? ?? 'inline',
      stickers:
          (json['stickers'] as List<dynamic>?)
              ?.map((item) {
                return StickerAsset.fromJson(
                  Map<String, dynamic>.from(item as Map),
                );
              })
              .toList() ??
          [],
    );
  }
}
