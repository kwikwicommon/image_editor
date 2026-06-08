import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/resource_store.dart';

/// Sticker category
enum StickerCategory {
  arrows,
  callouts,
  badges,
  emojis,
  decorations,
  custom;

  String get labelKey {
    switch (this) {
      case arrows:
        return 'stickers.category.arrows';
      case callouts:
        return 'stickers.category.callouts';
      case badges:
        return 'stickers.category.badges';
      case emojis:
        return 'stickers.category.emojis';
      case decorations:
        return 'stickers.category.decorations';
      case custom:
        return 'stickers.category.custom';
    }
  }

  IconData get icon {
    switch (this) {
      case arrows:
        return Icons.arrow_forward_rounded;
      case callouts:
        return Icons.chat_bubble_outline_rounded;
      case badges:
        return Icons.looks_one_rounded;
      case emojis:
        return Icons.emoji_emotions_outlined;
      case decorations:
        return Icons.auto_awesome_rounded;
      case custom:
        return Icons.folder_outlined;
    }
  }
}

/// Sticker format
enum StickerAssetFormat { svg, png }

StickerAsset withStickerResourceMetadata(StickerAsset sticker) {
  final svgContent = sticker.svgContent;
  if (svgContent != null && svgContent.isNotEmpty) {
    final hash = inlineResourceHashForText(svgContent);
    return sticker.copyWith(
      resourceId: 'sticker_${hash.substring(0, 24)}',
      resourceHash: hash,
      resourceByteSize: utf8.encode(svgContent).length,
    );
  }

  final dataBase64 = sticker.dataBase64;
  if (dataBase64 != null && dataBase64.isNotEmpty) {
    final bytes = base64Decode(dataBase64);
    final hash = inlineResourceHashForBytes(bytes);
    return sticker.copyWith(
      resourceId: 'sticker_${hash.substring(0, 24)}',
      resourceHash: hash,
      resourceByteSize: bytes.length,
    );
  }

  return sticker;
}

/// A single sticker asset
class StickerAsset {
  final String id;
  final String name;
  final StickerCategory category;
  final StickerAssetFormat format;
  final String assetPath;
  final bool isBuiltIn;
  final bool isRecolorable; // SVG stickers support recoloring
  final List<String> tags;
  final String? svgContent; // For inline SVG stickers
  final String? dataBase64; // For inline PNG stickers
  final String? resourceId;
  final String? resourceHash;
  final int? resourceByteSize;
  final String? customGroupId; // For custom sticker groups

  const StickerAsset({
    required this.id,
    required this.name,
    required this.category,
    this.format = StickerAssetFormat.svg,
    this.assetPath = '',
    this.isBuiltIn = true,
    this.isRecolorable = true,
    this.tags = const [],
    this.svgContent,
    this.dataBase64,
    this.resourceId,
    this.resourceHash,
    this.resourceByteSize,
    this.customGroupId,
  });

  StickerAsset copyWith({
    String? id,
    String? name,
    StickerCategory? category,
    StickerAssetFormat? format,
    String? assetPath,
    bool? isBuiltIn,
    bool? isRecolorable,
    List<String>? tags,
    String? svgContent,
    String? dataBase64,
    String? resourceId,
    String? resourceHash,
    int? resourceByteSize,
    String? customGroupId,
    bool clearCustomGroupId = false,
  }) {
    return StickerAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      format: format ?? this.format,
      assetPath: assetPath ?? this.assetPath,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isRecolorable: isRecolorable ?? this.isRecolorable,
      tags: tags ?? this.tags,
      svgContent: svgContent ?? this.svgContent,
      dataBase64: dataBase64 ?? this.dataBase64,
      resourceId: resourceId ?? this.resourceId,
      resourceHash: resourceHash ?? this.resourceHash,
      resourceByteSize: resourceByteSize ?? this.resourceByteSize,
      customGroupId: clearCustomGroupId
          ? null
          : customGroupId ?? this.customGroupId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'format': format.name,
    'assetPath': assetPath,
    'isBuiltIn': isBuiltIn,
    'isRecolorable': isRecolorable,
    'tags': tags,
    'svgContent': svgContent,
    'dataBase64': dataBase64,
    'resourceId': resourceId,
    'resourceHash': resourceHash,
    'resourceByteSize': resourceByteSize,
    'customGroupId': customGroupId,
  };

  factory StickerAsset.fromJson(Map<String, dynamic> json) => StickerAsset(
    id: json['id'] as String,
    name: json['name'] as String,
    category: StickerCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => StickerCategory.custom,
    ),
    format: json['format'] == 'png'
        ? StickerAssetFormat.png
        : StickerAssetFormat.svg,
    assetPath: json['assetPath'] as String? ?? '',
    isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    isRecolorable: json['isRecolorable'] as bool? ?? false,
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        [],
    svgContent: json['svgContent'] as String?,
    dataBase64: json['dataBase64'] as String?,
    resourceId: json['resourceId'] as String?,
    resourceHash: json['resourceHash'] as String?,
    resourceByteSize: (json['resourceByteSize'] as num?)?.toInt(),
    customGroupId: json['customGroupId'] as String?,
  );
}

class StickerResourceIndexEntry {
  final String id;
  final String contentHash;
  final int byteSize;
  final int refCount;

  const StickerResourceIndexEntry({
    required this.id,
    required this.contentHash,
    required this.byteSize,
    required this.refCount,
  });
}

/// Custom sticker group
class CustomStickerGroup {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<String> stickerIds;

  const CustomStickerGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    this.stickerIds = const [],
  });

  CustomStickerGroup copyWith({String? name, List<String>? stickerIds}) {
    return CustomStickerGroup(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      stickerIds: stickerIds ?? this.stickerIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'stickerIds': stickerIds,
  };

  factory CustomStickerGroup.fromJson(Map<String, dynamic> json) =>
      CustomStickerGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        stickerIds:
            (json['stickerIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}
