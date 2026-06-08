import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import 'built_in_stickers.dart';
import 'sticker_asset.dart';
import 'sticker_pack.dart';
import 'sticker_validation.dart';

abstract class StickerStorageAdapter {
  const StickerStorageAdapter();

  Future<Map<String, dynamic>?> readState();
  Future<void> writeState(Map<String, dynamic> state);
}

class MemoryStickerStorageAdapter extends StickerStorageAdapter {
  Map<String, dynamic>? _state;

  MemoryStickerStorageAdapter([Map<String, dynamic>? initialState])
    : _state = initialState == null ? null : _cloneJsonMap(initialState);

  @override
  Future<Map<String, dynamic>?> readState() async {
    final current = _state;
    return current == null ? null : _cloneJsonMap(current);
  }

  @override
  Future<void> writeState(Map<String, dynamic> state) async {
    _state = _cloneJsonMap(state);
  }
}

class StickerLibraryController extends GetxController {
  final selectedCategory = StickerCategory.arrows.obs;
  final searchQuery = ''.obs;
  final recentIds = <String>[].obs;
  final favoriteIds = <String>{}.obs;
  final customGroups = <CustomStickerGroup>[].obs;
  final customStickers = <StickerAsset>[].obs;

  StickerStorageAdapter _storage = MemoryStickerStorageAdapter();
  bool _isHydrating = false;
  Future<void> _persistTail = Future<void>.value();
  var _persistRevision = 0;
  var _idSequence = 0;

  List<StickerAsset> get allStickers => [
    ...BuiltInStickerLibrary.all,
    ...customStickers,
  ];

  List<StickerAsset> get filteredStickers {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      return allStickers.where((sticker) {
        return sticker.name.toLowerCase().contains(query) ||
            sticker.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }
    if (selectedCategory.value == StickerCategory.custom) {
      return customStickers.toList();
    }
    return BuiltInStickerLibrary.byCategory(selectedCategory.value);
  }

  List<StickerAsset> get recentStickers {
    return _stickersForIds(recentIds);
  }

  List<StickerAsset> get favoriteStickers {
    return _stickersForIds(favoriteIds);
  }

  List<StickerResourceIndexEntry> get customResourceIndex {
    final byHash = <String, StickerResourceIndexEntry>{};
    for (final sticker in customStickers) {
      final hash = sticker.resourceHash;
      final id = sticker.resourceId;
      if (hash == null || id == null) continue;
      final existing = byHash[hash];
      if (existing == null) {
        byHash[hash] = StickerResourceIndexEntry(
          id: id,
          contentHash: hash,
          byteSize: sticker.resourceByteSize ?? 0,
          refCount: 1,
        );
      } else {
        byHash[hash] = StickerResourceIndexEntry(
          id: existing.id,
          contentHash: existing.contentHash,
          byteSize: existing.byteSize,
          refCount: existing.refCount + 1,
        );
      }
    }
    return byHash.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> init(StickerStorageAdapter storage) async {
    _storage = storage;
    await load();
  }

  Future<void> load() async {
    _isHydrating = true;
    try {
      final state = await _storage.readState();
      if (state == null || state.isEmpty) return;
      try {
        _replaceFromJson(state);
      } on Object {
        _replaceFromJson(const {});
      }
    } finally {
      _isHydrating = false;
    }
  }

  void selectCategory(StickerCategory category) {
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;
    _persistInBackground();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  Future<void> addFavorite(String id) async {
    if (!favoriteIds.add(id)) return;
    await _persist();
  }

  Future<void> removeFavorite(String id) async {
    if (!favoriteIds.remove(id)) return;
    await _persist();
  }

  Future<void> toggleFavorite(String id) async {
    if (favoriteIds.contains(id)) {
      favoriteIds.remove(id);
    } else {
      favoriteIds.add(id);
    }
    await _persist();
  }

  Future<void> addRecent(String id) async {
    recentIds.remove(id);
    recentIds.insert(0, id);
    if (recentIds.length > 20) {
      recentIds.removeRange(20, recentIds.length);
    }
    await _persist();
  }

  Future<void> importSticker(StickerAsset asset) async {
    StickerAssetValidation.validateAsset(asset, source: asset.name);
    final effectiveGroupId = _existingGroupId(asset.customGroupId);
    final sticker = withStickerResourceMetadata(
      asset.copyWith(
        isBuiltIn: false,
        category: StickerCategory.custom,
        customGroupId: effectiveGroupId,
        clearCustomGroupId: effectiveGroupId == null,
      ),
    );
    final existingIndex = customStickers.indexWhere(
      (candidate) => candidate.id == sticker.id,
    );
    if (existingIndex == -1) {
      customStickers.add(sticker);
    } else {
      customStickers[existingIndex] = sticker;
    }
    if (effectiveGroupId != null) {
      _addStickerToGroupInMemory(effectiveGroupId, sticker.id);
    } else {
      _removeStickerFromGroupsInMemory(sticker.id);
    }
    await _persist();
  }

  Future<StickerAsset> importStickerFile({
    required String filePath,
    String? groupId,
    List<String> tags = const [],
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Sticker file was not found.', filePath);
    }

    final extension = path.extension(filePath).toLowerCase();
    final format = switch (extension) {
      '.svg' => StickerAssetFormat.svg,
      '.png' => StickerAssetFormat.png,
      _ => throw UnsupportedError('Unsupported sticker format.'),
    };

    final fileByteSize = await file.length();
    final maxByteSize = format == StickerAssetFormat.svg
        ? StickerAssetImportPolicy.maxSvgBytes
        : StickerAssetImportPolicy.maxPngBytes;
    if (fileByteSize > maxByteSize) {
      throw FormatException('Sticker file is too large.', filePath);
    }

    final bytes = await file.readAsBytes();
    final svgContent = format == StickerAssetFormat.svg
        ? _decodeSvgFile(bytes, filePath)
        : null;
    final dataBase64 = format == StickerAssetFormat.png
        ? base64Encode(bytes)
        : null;
    StickerAssetValidation.validateFile(
      filePath: filePath,
      format: format,
      bytes: bytes,
      svgContent: svgContent,
    );

    final effectiveGroupId = _existingGroupId(groupId);
    final id = _uniqueId('custom');
    final sticker = withStickerResourceMetadata(
      StickerAsset(
        id: id,
        name: path.basenameWithoutExtension(filePath),
        category: StickerCategory.custom,
        format: format,
        assetPath: filePath,
        isBuiltIn: false,
        isRecolorable: format == StickerAssetFormat.svg,
        tags: tags,
        svgContent: svgContent,
        dataBase64: dataBase64,
        customGroupId: effectiveGroupId,
      ),
    );

    await importSticker(sticker);
    return sticker;
  }

  Future<CustomStickerGroup> createGroup(String name) async {
    final normalizedName = name.trim().isEmpty ? 'Untitled Group' : name.trim();
    final group = CustomStickerGroup(
      id: _uniqueId('group'),
      name: normalizedName,
      createdAt: DateTime.now(),
    );
    customGroups.add(group);
    await _persist();
    return group;
  }

  Future<void> renameGroup(String groupId, String newName) async {
    final index = customGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) return;
    final normalizedName = newName.trim();
    if (normalizedName.isEmpty) return;
    customGroups[index] = customGroups[index].copyWith(name: normalizedName);
    await _persist();
  }

  Future<void> deleteGroup(String groupId) async {
    customGroups.removeWhere((group) => group.id == groupId);
    for (var index = 0; index < customStickers.length; index += 1) {
      final sticker = customStickers[index];
      if (sticker.customGroupId == groupId) {
        customStickers[index] = sticker.copyWith(clearCustomGroupId: true);
      }
    }
    await _persist();
  }

  Future<void> addStickerToGroup(String groupId, String stickerId) async {
    if (!_addStickerToGroupInMemory(groupId, stickerId)) return;
    await _persist();
  }

  Future<void> removeStickerFromGroup(String groupId, String stickerId) async {
    final index = customGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) return;
    final group = customGroups[index];
    var changed = false;
    if (group.stickerIds.contains(stickerId)) {
      customGroups[index] = group.copyWith(
        stickerIds: group.stickerIds.where((id) => id != stickerId).toList(),
      );
      changed = true;
    }
    final stickerIndex = customStickers.indexWhere(
      (sticker) => sticker.id == stickerId,
    );
    if (stickerIndex != -1 &&
        customStickers[stickerIndex].customGroupId == groupId) {
      customStickers[stickerIndex] = customStickers[stickerIndex].copyWith(
        clearCustomGroupId: true,
      );
      changed = true;
    }
    if (!changed) return;
    await _persist();
  }

  Future<void> removeCustomSticker(String id) async {
    customStickers.removeWhere((sticker) => sticker.id == id);
    favoriteIds.remove(id);
    recentIds.remove(id);
    for (var index = 0; index < customGroups.length; index += 1) {
      final group = customGroups[index];
      customGroups[index] = group.copyWith(
        stickerIds: group.stickerIds
            .where((stickerId) => stickerId != id)
            .toList(),
      );
    }
    await _persist();
  }

  Future<void> importPack(StickerPack pack) async {
    StickerAssetValidation.validatePack(pack, source: pack.name);
    final groupId = _uniqueId('pack');
    final importedStickers = <StickerAsset>[];
    final usedStickerIds = customStickers.map((sticker) => sticker.id).toSet();
    for (var index = 0; index < pack.stickers.length; index += 1) {
      final sticker = pack.stickers[index];
      final idSeed = _safeIdPart(
        sticker.id.isEmpty ? 'sticker_$index' : sticker.id,
      );
      importedStickers.add(
        withStickerResourceMetadata(
          StickerAsset(
            id: _uniqueIdWithSeed(
              '${groupId}_${index}_$idSeed',
              usedStickerIds,
            ),
            name: sticker.name,
            category: StickerCategory.custom,
            format: sticker.format,
            assetPath: sticker.assetPath,
            isBuiltIn: false,
            isRecolorable: sticker.isRecolorable,
            tags: sticker.tags,
            svgContent: sticker.svgContent,
            dataBase64: sticker.dataBase64,
            customGroupId: groupId,
          ),
        ),
      );
    }
    customStickers.addAll(importedStickers);
    customGroups.add(
      CustomStickerGroup(
        id: groupId,
        name: pack.name,
        createdAt: DateTime.now(),
        stickerIds: importedStickers.map((sticker) => sticker.id).toList(),
      ),
    );
    await _persist();
  }

  Future<void> importPackFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Sticker pack file was not found.', filePath);
    }
    if (await file.length() > StickerAssetImportPolicy.maxPackFileBytes) {
      throw FormatException('Sticker pack file is too large.', filePath);
    }
    final decoded = _decodeStickerPackJson(await file.readAsString(), filePath);
    if (decoded is! Map) {
      throw FormatException('Sticker pack JSON must be an object.', filePath);
    }
    late final StickerPack pack;
    try {
      pack = StickerPack.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      throw FormatException('Sticker pack structure is invalid.', filePath);
    }
    await importPack(pack);
  }

  Future<StickerPack> exportPack(
    String? groupId, {
    String? name,
    bool inlineResources = true,
  }) async {
    CustomStickerGroup? group;
    if (groupId != null) {
      for (final item in customGroups) {
        if (item.id == groupId) {
          group = item;
          break;
        }
      }
      if (group == null) {
        throw StateError('Sticker group was not found.');
      }
    }
    final stickerIds = group?.stickerIds.toSet();
    final stickers = stickerIds == null
        ? customStickers.toList()
        : customStickers
              .where((sticker) => stickerIds.contains(sticker.id))
              .toList();

    final exportStickers = <StickerAsset>[];
    for (final sticker in stickers) {
      exportStickers.add(
        await _copyStickerForPack(sticker, inlineResources: inlineResources),
      );
    }

    final pack = StickerPack(
      name: name ?? group?.name ?? 'Sticker Pack',
      resourceMode: inlineResources ? 'inline' : 'reference',
      stickers: exportStickers,
    );
    if (inlineResources) {
      StickerAssetValidation.validatePack(pack, source: pack.name);
    }
    return pack;
  }

  Future<String> exportPackToFile({
    required String name,
    String? groupId,
    String? outputPath,
    bool inlineResources = true,
  }) async {
    final pack = await exportPack(
      groupId,
      name: name,
      inlineResources: inlineResources,
    );
    final targetPath = outputPath ?? _defaultPackPath(name);
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(pack.toJson()));
    return targetPath;
  }

  Map<String, dynamic> toJson() {
    final sortedFavoriteIds = favoriteIds.toList()..sort();
    return {
      'selectedCategory': selectedCategory.value.name,
      'favoriteIds': sortedFavoriteIds,
      'recentIds': recentIds.toList(),
      'customStickers': customStickers
          .map((sticker) => sticker.toJson())
          .toList(),
      'customGroups': customGroups.map((group) => group.toJson()).toList(),
    };
  }

  Future<void> _persist() async {
    if (_isHydrating) return;
    final revision = ++_persistRevision;
    final write = _persistTail.catchError((Object _) {}).then((_) async {
      if (revision != _persistRevision) return;
      await _storage.writeState(toJson());
    });
    _persistTail = write;
    await write;
  }

  void _persistInBackground() {
    unawaited(_persist().catchError((Object _) {}));
  }

  void _replaceFromJson(Map<String, dynamic> json) {
    selectedCategory.value = StickerCategory.values.firstWhere(
      (category) => category.name == json['selectedCategory'],
      orElse: () => StickerCategory.arrows,
    );
    final parsedCustomStickers = _parseCustomStickers(json['customStickers']);
    final validStickerIds = {
      for (final sticker in BuiltInStickerLibrary.all) sticker.id,
      for (final sticker in parsedCustomStickers) sticker.id,
    };
    final customStickerIds = {
      for (final sticker in parsedCustomStickers) sticker.id,
    };
    favoriteIds
      ..clear()
      ..addAll(
        (json['favoriteIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where(validStickerIds.contains),
      );
    recentIds
      ..clear()
      ..addAll(
        (json['recentIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where(validStickerIds.contains),
      );
    customStickers.assignAll(parsedCustomStickers);
    customGroups.assignAll(
      _parseCustomGroups(json['customGroups'], customStickerIds),
    );
  }

  List<StickerAsset> _stickersForIds(Iterable<String> ids) {
    final byId = {for (final sticker in allStickers) sticker.id: sticker};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<StickerAsset> _copyStickerForPack(
    StickerAsset sticker, {
    required bool inlineResources,
  }) async {
    var svgContent = sticker.svgContent;
    var dataBase64 = sticker.dataBase64;
    final assetPath = sticker.assetPath;

    if (inlineResources) {
      if (sticker.format == StickerAssetFormat.svg &&
          (svgContent == null || svgContent.isEmpty) &&
          assetPath.isNotEmpty) {
        final file = File(assetPath);
        if (!await file.exists()) {
          throw FileSystemException(
            'Sticker SVG file was not found.',
            assetPath,
          );
        }
        if (await file.length() > StickerAssetImportPolicy.maxSvgBytes) {
          throw FormatException('Sticker SVG is too large.', assetPath);
        }
        svgContent = _decodeSvgFile(await file.readAsBytes(), assetPath);
      }
      if (sticker.format == StickerAssetFormat.png &&
          (dataBase64 == null || dataBase64.isEmpty) &&
          assetPath.isNotEmpty) {
        final file = File(assetPath);
        if (!await file.exists()) {
          throw FileSystemException(
            'Sticker PNG file was not found.',
            assetPath,
          );
        }
        if (await file.length() > StickerAssetImportPolicy.maxPngBytes) {
          throw FormatException('Sticker PNG is too large.', assetPath);
        }
        dataBase64 = base64Encode(await file.readAsBytes());
      }
    }

    final copied = sticker.copyWith(
      category: StickerCategory.custom,
      isBuiltIn: false,
      assetPath: inlineResources ? '' : assetPath,
      svgContent: svgContent,
      dataBase64: dataBase64,
    );
    StickerAssetValidation.validateAsset(copied, source: sticker.name);
    return withStickerResourceMetadata(copied);
  }

  List<StickerAsset> _parseCustomStickers(Object? rawStickers) {
    final parsedStickers = <StickerAsset>[];
    final seenIds = <String>{};
    final items = rawStickers is List ? rawStickers : const [];
    for (final item in items) {
      if (item is! Map) continue;
      try {
        final sticker = withStickerResourceMetadata(
          StickerAsset.fromJson(Map<String, dynamic>.from(item)),
        );
        StickerAssetValidation.validateAsset(sticker, source: sticker.name);
        if (!seenIds.add(sticker.id)) continue;
        parsedStickers.add(sticker);
      } on Object {
        continue;
      }
    }
    return parsedStickers;
  }

  List<CustomStickerGroup> _parseCustomGroups(
    Object? rawGroups,
    Set<String> validStickerIds,
  ) {
    final parsedGroups = <CustomStickerGroup>[];
    final assignedStickerIds = <String>{};
    final seenGroupIds = <String>{};
    final items = rawGroups is List ? rawGroups : const [];
    for (final item in items) {
      if (item is! Map) continue;
      try {
        final group = CustomStickerGroup.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (!seenGroupIds.add(group.id)) continue;
        final stickerIds = <String>[];
        for (final stickerId in group.stickerIds) {
          if (validStickerIds.contains(stickerId) &&
              assignedStickerIds.add(stickerId)) {
            stickerIds.add(stickerId);
          }
        }
        parsedGroups.add(group.copyWith(stickerIds: stickerIds));
      } on Object {
        continue;
      }
    }
    return parsedGroups;
  }

  bool _addStickerToGroupInMemory(String groupId, String stickerId) {
    final groupIndex = customGroups.indexWhere((group) => group.id == groupId);
    if (groupIndex == -1) return false;
    final stickerIndex = customStickers.indexWhere(
      (sticker) => sticker.id == stickerId,
    );
    if (stickerIndex == -1) return false;

    var changed = false;
    for (var index = 0; index < customGroups.length; index += 1) {
      if (index == groupIndex) continue;
      final otherGroup = customGroups[index];
      if (otherGroup.stickerIds.contains(stickerId)) {
        customGroups[index] = otherGroup.copyWith(
          stickerIds: otherGroup.stickerIds
              .where((id) => id != stickerId)
              .toList(),
        );
        changed = true;
      }
    }

    final group = customGroups[groupIndex];
    if (!group.stickerIds.contains(stickerId)) {
      customGroups[groupIndex] = group.copyWith(
        stickerIds: [...group.stickerIds, stickerId],
      );
      changed = true;
    }

    final sticker = customStickers[stickerIndex];
    if (sticker.customGroupId != groupId) {
      customStickers[stickerIndex] = sticker.copyWith(customGroupId: groupId);
      changed = true;
    }
    return changed;
  }

  bool _removeStickerFromGroupsInMemory(String stickerId) {
    var changed = false;
    for (var index = 0; index < customGroups.length; index += 1) {
      final group = customGroups[index];
      if (group.stickerIds.contains(stickerId)) {
        customGroups[index] = group.copyWith(
          stickerIds: group.stickerIds.where((id) => id != stickerId).toList(),
        );
        changed = true;
      }
    }
    return changed;
  }

  String? _existingGroupId(String? groupId) {
    if (groupId == null) return null;
    return customGroups.any((group) => group.id == groupId) ? groupId : null;
  }

  String _uniqueId(String prefix) {
    final sequence = _idSequence;
    _idSequence += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$sequence';
  }

  String _uniqueIdWithSeed(String seed, Set<String> usedIds) {
    final base = _safeIdPart(seed);
    final prefix = base.isEmpty ? 'item' : base;
    var candidate = prefix;
    var suffix = 1;
    while (usedIds.contains(candidate)) {
      candidate = '${prefix}_$suffix';
      suffix += 1;
    }
    usedIds.add(candidate);
    return candidate;
  }

  String _safeIdPart(String value) {
    return value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Object? _decodeStickerPackJson(String content, String source) {
    try {
      return jsonDecode(content);
    } on FormatException catch (error) {
      throw FormatException(
        'Sticker pack JSON is invalid.',
        source,
        error.offset,
      );
    }
  }

  String _decodeSvgFile(List<int> bytes, String source) {
    try {
      return utf8.decode(bytes);
    } on FormatException catch (error) {
      throw FormatException(
        'Sticker SVG must be valid UTF-8.',
        source,
        error.offset,
      );
    }
  }

  String _defaultPackPath(String name) {
    final safeName = _safeIdPart(name);
    final baseName = safeName.isEmpty ? 'sticker_pack' : safeName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.join(Directory.current.path, '${baseName}_$timestamp.json');
  }
}

Map<String, dynamic> _cloneJsonMap(Map<String, dynamic> source) {
  final decoded = jsonDecode(jsonEncode(source)) as Map;
  return Map<String, dynamic>.from(decoded);
}
