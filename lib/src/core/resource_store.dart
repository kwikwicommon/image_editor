import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class InlineResourceBudgetExceededException implements Exception {
  final String message;

  const InlineResourceBudgetExceededException(this.message);

  @override
  String toString() => message;
}

class InlineResourceBudget {
  static const standard = InlineResourceBudget(
    maxInlineResourceBytes: 24 * 1024 * 1024,
    maxInlineTotalBytes: 64 * 1024 * 1024,
    maxResourceCount: 256,
  );

  final int maxInlineResourceBytes;
  final int maxInlineTotalBytes;
  final int maxResourceCount;

  const InlineResourceBudget({
    required this.maxInlineResourceBytes,
    required this.maxInlineTotalBytes,
    required this.maxResourceCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'maxInlineResourceBytes': maxInlineResourceBytes,
      'maxInlineTotalBytes': maxInlineTotalBytes,
      'maxResourceCount': maxResourceCount,
    };
  }
}

class InlineStoredResource {
  final String id;
  final String kind;
  final String storage;
  final String encoding;
  final String contentHash;
  final int byteSize;
  final int refCount;
  final String? text;
  final String? dataBase64;
  final String? data;

  const InlineStoredResource({
    required this.id,
    required this.kind,
    required this.storage,
    required this.encoding,
    required this.contentHash,
    required this.byteSize,
    required this.refCount,
    this.text,
    this.dataBase64,
    this.data,
  });

  InlineStoredResource copyWith({int? refCount}) {
    return InlineStoredResource(
      id: id,
      kind: kind,
      storage: storage,
      encoding: encoding,
      contentHash: contentHash,
      byteSize: byteSize,
      refCount: refCount ?? this.refCount,
      text: text,
      dataBase64: dataBase64,
      data: data,
    );
  }

  String? get textPayload {
    if (text != null) return text;
    return encoding == 'utf8' ? data : null;
  }

  String? get base64Payload {
    if (dataBase64 != null) return dataBase64;
    return encoding == 'base64' ? data : null;
  }

  Map<String, dynamic> toDescriptorJson() {
    return {
      'id': id,
      'kind': kind,
      'storage': storage,
      'encoding': encoding,
      'contentHash': contentHash,
      'byteSize': byteSize,
      'refCount': refCount,
    };
  }

  Map<String, dynamic> toPayloadJson() {
    return {
      ...toDescriptorJson(),
      'data': data ?? base64Payload ?? textPayload,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind,
      'storage': storage,
      'encoding': encoding,
      'contentHash': contentHash,
      'byteSize': byteSize,
      'refCount': refCount,
      'text': text,
      'dataBase64': dataBase64,
      'data': data,
    };
  }

  factory InlineStoredResource.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String?;
    final dataBase64 = json['dataBase64'] as String?;
    final data = json['data'] as String?;
    final encoding =
        json['encoding'] as String? ??
        (dataBase64 != null ? 'base64' : null) ??
        (text != null ? 'utf8' : null) ??
        '';
    return InlineStoredResource(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      storage: json['storage'] as String? ?? '',
      encoding: encoding,
      contentHash: json['contentHash'] as String? ?? '',
      byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
      refCount: (json['refCount'] as num?)?.toInt() ?? 0,
      text: text,
      dataBase64: dataBase64,
      data: data,
    );
  }
}

class InlineResourceStore {
  final List<InlineStoredResource> resources;

  InlineResourceStore({required List<InlineStoredResource> resources})
    : resources = List.unmodifiable(resources);

  static final empty = InlineResourceStore(resources: const []);

  Map<String, InlineStoredResource> get byId {
    return {for (final resource in resources) resource.id: resource};
  }

  String? textFor(String? id) {
    if (id == null || id.isEmpty) return null;
    return byId[id]?.textPayload;
  }

  String? dataBase64For(String? id) {
    if (id == null || id.isEmpty) return null;
    return byId[id]?.base64Payload;
  }

  Map<String, dynamic> toResourcePayloadMap() {
    return {
      for (final resource in resources) resource.id: resource.toPayloadJson(),
    };
  }

  Map<String, dynamic> toResourceManifestJson({
    InlineResourceBudget budget = InlineResourceBudget.standard,
  }) {
    return {
      'mode': 'manifest',
      'resources': resources
          .map((resource) => resource.toDescriptorJson())
          .toList(),
      'budget': budget.toJson(),
    };
  }

  void ensureWithinBudget({
    InlineResourceBudget budget = InlineResourceBudget.standard,
  }) {
    if (resources.length > budget.maxResourceCount) {
      throw InlineResourceBudgetExceededException(
        'Inline resource count ${resources.length} exceeds '
        '${budget.maxResourceCount}.',
      );
    }

    var totalBytes = 0;
    for (final resource in resources) {
      if (resource.byteSize > budget.maxInlineResourceBytes) {
        throw InlineResourceBudgetExceededException(
          'Inline resource ${resource.id} has ${resource.byteSize} bytes, '
          'which exceeds ${budget.maxInlineResourceBytes}.',
        );
      }
      totalBytes += resource.byteSize;
    }

    if (totalBytes > budget.maxInlineTotalBytes) {
      throw InlineResourceBudgetExceededException(
        'Inline resource total $totalBytes exceeds '
        '${budget.maxInlineTotalBytes}.',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': 'inline',
      'resources': resources.map((resource) => resource.toJson()).toList(),
    };
  }

  factory InlineResourceStore.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    final list = raw['resources'];
    if (list is! List) return empty;
    return InlineResourceStore(
      resources: list
          .whereType<Map>()
          .map((item) => InlineStoredResource.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((resource) => resource.id.isNotEmpty)
          .toList(),
    );
  }
}

class InlineResourceStoreBuilder {
  final Map<String, InlineStoredResource> _resourcesByKey = {};

  InlineStoredResource addText({
    required String kind,
    required String text,
    String storage = 'manifest',
  }) {
    final bytes = utf8.encode(text);
    return _add(
      kind: kind,
      storage: storage,
      encoding: 'utf8',
      bytes: bytes,
      text: text,
      dataBase64: null,
      data: text,
    );
  }

  InlineStoredResource addBase64({
    required String kind,
    required String dataBase64,
    String storage = 'manifest',
  }) {
    final bytes = base64Decode(dataBase64);
    return _add(
      kind: kind,
      storage: storage,
      encoding: 'base64',
      bytes: bytes,
      text: null,
      dataBase64: dataBase64,
      data: dataBase64,
    );
  }

  InlineStoredResource addBytes({
    required String kind,
    required Uint8List bytes,
    String storage = 'manifest',
  }) {
    final dataBase64 = base64Encode(bytes);
    return _add(
      kind: kind,
      storage: storage,
      encoding: 'base64',
      bytes: bytes,
      text: null,
      dataBase64: dataBase64,
      data: dataBase64,
    );
  }

  InlineStoredResource _add({
    required String kind,
    required String storage,
    required String encoding,
    required List<int> bytes,
    required String? text,
    required String? dataBase64,
    required String? data,
  }) {
    final contentHash = sha256.convert(bytes).toString();
    final key = '$storage:$encoding:$kind:$contentHash';
    final existing = _resourcesByKey[key];
    if (existing != null) {
      final next = existing.copyWith(refCount: existing.refCount + 1);
      _resourcesByKey[key] = next;
      return next;
    }

    final resource = InlineStoredResource(
      id: 'res_${_safeKind(kind)}_${contentHash.substring(0, 24)}',
      kind: kind,
      storage: storage,
      encoding: encoding,
      contentHash: contentHash,
      byteSize: bytes.length,
      refCount: 1,
      text: text,
      dataBase64: dataBase64,
      data: data,
    );
    _resourcesByKey[key] = resource;
    return resource;
  }

  InlineResourceStore build() {
    final resources = _resourcesByKey.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return InlineResourceStore(resources: resources);
  }

  String _safeKind(String kind) {
    return kind.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }
}

String inlineResourceHashForBytes(Uint8List bytes) {
  return sha256.convert(bytes).toString();
}

String inlineResourceHashForText(String value) {
  return sha256.convert(utf8.encode(value)).toString();
}
