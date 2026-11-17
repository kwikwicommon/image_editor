import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../background/background_state.dart';
import '../background/background_state_codec.dart';
import '../canvas/annotation_element.dart';
import '../canvas/annotation_json.dart';
import '../core/image_editor_localizations.dart';
import '../core/resource_store.dart';
import 'project_file.dart';

class _ProjectResourceBundle {
  final InlineResourceStore store;
  final Map<String, String> logicalRefs;

  const _ProjectResourceBundle({
    required this.store,
    required this.logicalRefs,
  });

  InlineStoredResource? resourceForLogical(String logicalId) {
    final resourceId = logicalRefs[logicalId];
    if (resourceId == null) return null;
    return store.byId[resourceId];
  }
}

class ProjectCodec {
  final ImageEditorLocalizations localizations;
  final InlineResourceBudget resourceBudget;

  const ProjectCodec({
    this.localizations = const DefaultImageEditorLocalizations(),
    this.resourceBudget = InlineResourceBudget.standard,
  });

  Map<String, dynamic> encode(ProjectFile file) {
    _ensureSupportedVersion(file.version);
    final snapshot = file.snapshot;
    final imageBytes = snapshot.imageRef.bytes;
    final resourceBundle = _buildResourceBundle(snapshot);
    resourceBundle.store.ensureWithinBudget(budget: resourceBudget);
    final backgroundState = _backgroundStateToJson(
      snapshot.backgroundState,
      resourceBundle,
      includeLegacyCustomImage: true,
    );
    final backgroundSettings = _backgroundStateToJson(
      snapshot.backgroundState,
      resourceBundle,
      includeLegacyCustomImage: false,
    );
    return {
      'projectFileVersion': file.version,
      'version': '1.0',
      'resourceMode': 'manifest',
      'resourceManifest': resourceBundle.store.toResourceManifestJson(
        budget: resourceBudget,
      ),
      'resources': resourceBundle.store.toResourcePayloadMap(),
      'createdAt': file.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'canvasSize': _sizeToJson(snapshot.imageRef.size),
      'backgroundImageRef': resourceBundle.logicalRefs['backgroundImage'],
      'imageRef': {
        'id': snapshot.imageRef.id,
        'path': snapshot.imageRef.path,
        'bytes': imageBytes == null ? null : base64Encode(imageBytes),
        'resourceId': resourceBundle.logicalRefs['backgroundImage'],
        'resourceHash': resourceBundle
            .resourceForLogical('backgroundImage')
            ?.contentHash,
        'size': _sizeToJson(snapshot.imageRef.size),
      },
      'elements': snapshot.elements
          .map((element) => _elementToJson(element, resourceBundle))
          .toList(),
      'backgroundState': backgroundState,
      'backgroundSettings': backgroundSettings,
      if (file.externalSourceRef != null)
        'externalSourceRef': file.externalSourceRef!.toJson(),
    };
  }

  String encodeString(ProjectFile file) {
    return jsonEncode(encode(file));
  }

  ProjectFile decodeString(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    return decode(Map<String, dynamic>.from(decoded));
  }

  ProjectFile decode(Map<String, dynamic> json) {
    var version = _versionFromJson(json);
    var workingJson = json;
    if (version < ProjectFile.currentVersion) {
      workingJson = ProjectSchemaMigrator.migrate(
        json,
        fromVersion: version,
        toVersion: ProjectFile.currentVersion,
      );
      version = ProjectFile.currentVersion;
    }
    _ensureSupportedVersion(version);

    final resources = _resourcesFromJson(workingJson['resources']);
    final imageRefJson = workingJson['imageRef'] is Map
        ? Map<String, dynamic>.from(workingJson['imageRef'] as Map)
        : <String, dynamic>{};
    final elementsJson = workingJson['elements'] as List<dynamic>? ?? const [];
    final elements = <AnnotationElement>[];
    for (final rawElement in elementsJson) {
      if (rawElement is! Map) continue;
      final elementJson = Map<String, dynamic>.from(rawElement);
      _resolveElementResourceRefs(elementJson, resources);
      final element = AnnotationElementJson.fromJson(elementJson);
      if (element != null) elements.add(element);
    }

    final rawBackgroundJson =
        workingJson['backgroundState'] ?? workingJson['backgroundSettings'];
    if (rawBackgroundJson != null && rawBackgroundJson is! Map) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    final backgroundJson = rawBackgroundJson == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(rawBackgroundJson);
    _resolveBackgroundResourceRefs(backgroundJson, resources);
    final backgroundState = backgroundJson.isEmpty
        ? const BackgroundState()
        : BackgroundStateCodec.fromJson(backgroundJson);
    final canvasSize = _sizeFromJson(workingJson['canvasSize']);

    ExternalSourceRef? externalSourceRef;
    final extRefJson = workingJson['externalSourceRef'];
    if (extRefJson is Map) {
      externalSourceRef = ExternalSourceRef.fromJson(
        Map<String, dynamic>.from(extRefJson),
      );
    }

    return ProjectFile(
      version: version,
      createdAt:
          DateTime.tryParse(
            _optionalStringFromJson(workingJson, 'createdAt') ?? '',
          ) ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(
            _optionalStringFromJson(workingJson, 'updatedAt') ?? '',
          ) ?? DateTime.now(),
      externalSourceRef: externalSourceRef,
      snapshot: ProjectSnapshot(
        elements: elements,
        backgroundState: backgroundState,
        imageRef: ProjectImageRef(
          id: _optionalStringFromJson(imageRefJson, 'id') ?? 'source',
          path: _optionalStringFromJson(imageRefJson, 'path'),
          bytes: _imageBytesFromJson(workingJson, imageRefJson, resources),
          size: _sizeFromJson(imageRefJson['size']) ?? canvasSize,
        ),
      ),
    );
  }

  bool isVersionSupported(int version) {
    return version >= 1 && version <= ProjectFile.currentVersion;
  }

  int _versionFromJson(Map<String, dynamic> json) {
    final rawVersion = json['projectFileVersion'];
    if (rawVersion == null) return ProjectFile.currentVersion;
    if (rawVersion is! num) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    return rawVersion.toInt();
  }

  void _ensureSupportedVersion(int version) {
    if (version < 1) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    if (!isVersionSupported(version)) {
      throw UnsupportedProjectVersionException(
        localizations.params('error.projectUnsupportedVersion', {
          'version': '$version',
        }),
      );
    }
  }

  _ProjectResourceBundle _buildResourceBundle(ProjectSnapshot snapshot) {
    final builder = InlineResourceStoreBuilder();
    final logicalRefs = <String, String>{};

    void addBytesResource({
      required String logicalId,
      required String kind,
      required Uint8List? bytes,
    }) {
      if (bytes == null || bytes.isEmpty) return;
      final resource = builder.addBytes(kind: kind, bytes: bytes);
      logicalRefs[logicalId] = resource.id;
    }

    void addBase64Resource({
      required String logicalId,
      required String kind,
      required String? dataBase64,
    }) {
      if (dataBase64 == null || dataBase64.isEmpty) return;
      final resource = builder.addBase64(kind: kind, dataBase64: dataBase64);
      logicalRefs[logicalId] = resource.id;
    }

    void addTextResource({
      required String logicalId,
      required String kind,
      required String? text,
    }) {
      if (text == null || text.isEmpty) return;
      final resource = builder.addText(kind: kind, text: text);
      logicalRefs[logicalId] = resource.id;
    }

    addBytesResource(
      logicalId: 'backgroundImage',
      kind: 'backgroundImage',
      bytes: snapshot.imageRef.bytes,
    );
    addBytesResource(
      logicalId: 'backgroundSettings.customImage',
      kind: 'backgroundImage',
      bytes: snapshot.backgroundState.customImageBytes,
    );

    for (final element in snapshot.elements.whereType<StickerElement>()) {
      addBase64Resource(
        logicalId: 'element:${element.id}:dataBase64',
        kind: 'stickerImage',
        dataBase64: element.dataBase64,
      );
      addTextResource(
        logicalId: 'element:${element.id}:svgContent',
        kind: 'stickerSvg',
        text: element.svgContent,
      );
    }

    return _ProjectResourceBundle(
      store: builder.build(),
      logicalRefs: Map.unmodifiable(logicalRefs),
    );
  }

  Map<String, dynamic> _backgroundStateToJson(
    BackgroundState state,
    _ProjectResourceBundle resourceBundle, {
    required bool includeLegacyCustomImage,
  }) {
    return BackgroundStateCodec.toJson(
      state,
      customImageRef:
          resourceBundle.logicalRefs['backgroundSettings.customImage'],
      includeLegacyCustomImage: includeLegacyCustomImage,
    );
  }

  Map<String, dynamic> _elementToJson(
    AnnotationElement element,
    _ProjectResourceBundle resourceBundle,
  ) {
    final json = element.toJson();
    if (element is! StickerElement) return json;

    final dataRef =
        resourceBundle.logicalRefs['element:${element.id}:dataBase64'];
    if (dataRef != null) {
      final payload = resourceBundle.store.byId[dataRef];
      json.remove('dataBase64');
      json['dataResourceId'] = dataRef;
      json['resourceId'] = dataRef;
      json['resourceHash'] = payload?.contentHash;
    }

    final svgRef =
        resourceBundle.logicalRefs['element:${element.id}:svgContent'];
    if (svgRef != null) {
      final payload = resourceBundle.store.byId[svgRef];
      json.remove('svgContent');
      json['svgResourceId'] = svgRef;
      json['resourceId'] = svgRef;
      json['resourceHash'] = payload?.contentHash;
    }

    return json;
  }

  static Map<String, dynamic>? _sizeToJson(Size? size) {
    if (size == null) return null;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return null;
    }
    return {'width': size.width, 'height': size.height};
  }

  static Size? _sizeFromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final width = json['width'];
    final height = json['height'];
    if (width is! num || height is! num) return null;
    final size = Size(width.toDouble(), height.toDouble());
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return null;
    }
    return size;
  }

  Map<String, InlineStoredResource> _resourcesFromJson(Object? value) {
    if (value == null) return const {};

    final resources = <String, InlineStoredResource>{};
    var reservedBytes = 0;
    if (value is Map) {
      for (final entry in value.entries) {
        final resourceId = entry.key;
        final rawResource = entry.value;
        if (resourceId is! String || rawResource is! Map) {
          throw FormatException(
            localizations.text('error.projectPayloadInvalid'),
          );
        }
        final resourceJson = Map<String, dynamic>.from(rawResource);
        _ensureResourceCountCanLoad(resources.length + 1);
        final resource = _resourceFromJson(
          resourceJson,
          mapId: resourceId,
          reservedBytes: reservedBytes,
        );
        if (resources.containsKey(resource.id)) {
          throw FormatException(
            localizations.text('error.projectPayloadInvalid'),
          );
        }
        resources[resource.id] = resource;
        reservedBytes += resource.byteSize;
      }
      _ensureResourcesWithinBudget(resources.values);
      return Map.unmodifiable(resources);
    }

    if (value is List) {
      for (final rawResource in value) {
        if (rawResource is! Map) continue;
        _ensureResourceCountCanLoad(resources.length + 1);
        final resource = _resourceFromJson(
          Map<String, dynamic>.from(rawResource),
          reservedBytes: reservedBytes,
        );
        if (resources.containsKey(resource.id)) {
          throw FormatException(
            localizations.text('error.projectPayloadInvalid'),
          );
        }
        resources[resource.id] = resource;
        reservedBytes += resource.byteSize;
      }
      _ensureResourcesWithinBudget(resources.values);
      return Map.unmodifiable(resources);
    }

    throw FormatException(localizations.text('error.projectPayloadInvalid'));
  }

  InlineStoredResource _resourceFromJson(
    Map<String, dynamic> json, {
    String? mapId,
    required int reservedBytes,
  }) {
    final rawId = json['id'];
    final id = rawId ?? mapId;
    if (id is! String || id.isEmpty || (mapId != null && id != mapId)) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }

    final rawEncoding = _optionalStringFromJson(json, 'encoding');
    final encoding = rawEncoding ?? _inferResourceEncoding(json);
    if (encoding != 'base64' && encoding != 'utf8') {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }

    final rawByteSize = json['byteSize'];
    final declaredByteSize = rawByteSize == null
        ? null
        : _nonNegativeIntFromJson(rawByteSize);
    final rawRefCount = json['refCount'];
    final refCount = rawRefCount == null
        ? 0
        : _nonNegativeIntFromJson(rawRefCount);
    final actualByteSize = _resourceByteSize(json, encoding);
    if (declaredByteSize != null && declaredByteSize != actualByteSize) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    _ensureResourceBytesCanLoad(
      id: id,
      byteSize: actualByteSize,
      reservedBytes: reservedBytes,
    );

    final resource = InlineStoredResource(
      id: id,
      kind: _optionalStringFromJson(json, 'kind') ?? '',
      storage: _optionalStringFromJson(json, 'storage') ?? '',
      encoding: encoding,
      contentHash: _optionalStringFromJson(json, 'contentHash') ?? '',
      byteSize: actualByteSize,
      refCount: refCount,
      text: _optionalStringFromJson(json, 'text'),
      dataBase64: _optionalStringFromJson(json, 'dataBase64'),
      data: _optionalStringFromJson(json, 'data'),
    );
    _verifyResourcePayload(resource);
    return resource;
  }

  String? _optionalStringFromJson(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException(localizations.text('error.projectPayloadInvalid'));
  }

  String _inferResourceEncoding(Map<String, dynamic> json) {
    if (json['dataBase64'] != null) return 'base64';
    if (json['text'] != null) return 'utf8';
    final storage = json['storage'];
    if (storage == 'inlineText') return 'utf8';
    if (storage == 'inlineBase64' || storage == 'manifest') return 'base64';
    return '';
  }

  int _resourceByteSize(Map<String, dynamic> json, String encoding) {
    if (encoding == 'base64') {
      return _base64DecodedLength(_base64PayloadFromJson(json));
    }
    if (encoding == 'utf8') {
      return utf8.encode(_utf8PayloadFromJson(json)).length;
    }
    throw FormatException(localizations.text('error.projectPayloadInvalid'));
  }

  String _base64PayloadFromJson(Map<String, dynamic> json) {
    final value = json['dataBase64'] ?? json['data'];
    if (value is! String || value.isEmpty) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    return value;
  }

  String _utf8PayloadFromJson(Map<String, dynamic> json) {
    final value = json['text'] ?? json['data'];
    if (value is! String) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    return value;
  }

  int _nonNegativeIntFromJson(Object? value) {
    if (value is! num || !value.isFinite) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    final intValue = value.toInt();
    if (intValue.toDouble() != value.toDouble() || intValue < 0) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    return intValue;
  }

  int _base64DecodedLength(String data) {
    try {
      final normalized = base64.normalize(data);
      if (normalized.isEmpty) return 0;
      var padding = 0;
      if (normalized.endsWith('==')) {
        padding = 2;
      } else if (normalized.endsWith('=')) {
        padding = 1;
      }
      return (normalized.length ~/ 4) * 3 - padding;
    } on FormatException {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
  }

  void _ensureResourceCountCanLoad(int count) {
    if (count > resourceBudget.maxResourceCount) {
      throw InlineResourceBudgetExceededException(
        'Inline resource count $count exceeds '
        '${resourceBudget.maxResourceCount}.',
      );
    }
  }

  void _ensureResourceBytesCanLoad({
    required String id,
    required int byteSize,
    required int reservedBytes,
  }) {
    if (byteSize > resourceBudget.maxInlineResourceBytes) {
      throw InlineResourceBudgetExceededException(
        'Inline resource $id has $byteSize bytes, '
        'which exceeds ${resourceBudget.maxInlineResourceBytes}.',
      );
    }
    final nextTotal = reservedBytes + byteSize;
    if (nextTotal > resourceBudget.maxInlineTotalBytes) {
      throw InlineResourceBudgetExceededException(
        'Inline resource total $nextTotal exceeds '
        '${resourceBudget.maxInlineTotalBytes}.',
      );
    }
  }

  void _ensureResourcesWithinBudget(Iterable<InlineStoredResource> resources) {
    InlineResourceStore(
      resources: resources.toList(),
    ).ensureWithinBudget(budget: resourceBudget);
  }

  void _verifyResourcePayload(InlineStoredResource resource) {
    if (resource.encoding == 'base64') {
      _decodeBase64Resource(resource);
      return;
    }
    if (resource.encoding == 'utf8') {
      final text = resource.textPayload;
      if (text == null) {
        throw FormatException(
          localizations.text('error.projectPayloadInvalid'),
        );
      }
      final actualByteSize = utf8.encode(text).length;
      if (resource.byteSize != actualByteSize) {
        throw FormatException(
          localizations.text('error.projectPayloadInvalid'),
        );
      }
      final expectedHash = resource.contentHash;
      if (expectedHash.isNotEmpty &&
          expectedHash != inlineResourceHashForText(text)) {
        throw FormatException(
          localizations.text('error.projectPayloadInvalid'),
        );
      }
      return;
    }
    throw FormatException(localizations.text('error.projectPayloadInvalid'));
  }

  Uint8List? _imageBytesFromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> imageRefJson,
    Map<String, InlineStoredResource> resources,
  ) {
    final imageRefBytes = _optionalInlineBase64Decode(
      imageRefJson['bytes'],
      logicalId: 'imageRef.bytes',
    );
    if (imageRefBytes != null) return imageRefBytes;

    final legacyBackgroundBytes = _optionalInlineBase64Decode(
      json['backgroundImage'],
      logicalId: 'backgroundImage',
    );
    if (legacyBackgroundBytes != null) return legacyBackgroundBytes;

    final resourceId =
        _optionalStringFromJson(imageRefJson, 'resourceId') ??
        _optionalStringFromJson(json, 'backgroundImageRef');
    if (resourceId == null || resourceId.isEmpty) return null;
    return _base64ResourceBytes(resources, resourceId);
  }

  void _resolveBackgroundResourceRefs(
    Map<String, dynamic> json,
    Map<String, InlineStoredResource> resources,
  ) {
    final customImageRef = _optionalStringFromJson(json, 'customImageRef');
    if (customImageRef == null || json['customImage'] != null) return;
    json['customImage'] = _base64ResourceData(resources, customImageRef);
  }

  void _resolveElementResourceRefs(
    Map<String, dynamic> json,
    Map<String, InlineStoredResource> resources,
  ) {
    final dataResourceId = _optionalStringFromJson(json, 'dataResourceId');
    if (dataResourceId != null && json['dataBase64'] == null) {
      json['dataBase64'] = _base64ResourceData(resources, dataResourceId);
      final payload = _resourcePayload(resources, dataResourceId);
      json['resourceId'] = dataResourceId;
      json['resourceHash'] = payload.contentHash;
    }

    final svgResourceId = _optionalStringFromJson(json, 'svgResourceId');
    if (svgResourceId != null && json['svgContent'] == null) {
      json['svgContent'] = _utf8ResourceData(resources, svgResourceId);
      final payload = _resourcePayload(resources, svgResourceId);
      json['resourceId'] = svgResourceId;
      json['resourceHash'] = payload.contentHash;
    }

    final resourceId = _optionalStringFromJson(json, 'resourceId');
    if (resourceId == null) return;
    final format = _optionalStringFromJson(json, 'format');
    if (format == 'png' && json['dataBase64'] == null) {
      json['dataBase64'] = _base64ResourceData(resources, resourceId);
      json['resourceHash'] = _resourcePayload(
        resources,
        resourceId,
      ).contentHash;
    }
    if (format == 'svg' && json['svgContent'] == null) {
      json['svgContent'] = _utf8ResourceData(resources, resourceId);
      json['resourceHash'] = _resourcePayload(
        resources,
        resourceId,
      ).contentHash;
    }
  }

  InlineStoredResource _resourcePayload(
    Map<String, InlineStoredResource> resources,
    String id,
  ) {
    final payload = resources[id];
    if (payload == null) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    return payload;
  }

  String _base64ResourceData(
    Map<String, InlineStoredResource> resources,
    String id,
  ) {
    final payload = _resourcePayload(resources, id);
    _decodeBase64Resource(payload);
    return payload.base64Payload!;
  }

  String _utf8ResourceData(
    Map<String, InlineStoredResource> resources,
    String id,
  ) {
    final payload = _resourcePayload(resources, id);
    _verifyResourcePayload(payload);
    return payload.textPayload!;
  }

  Uint8List _base64ResourceBytes(
    Map<String, InlineStoredResource> resources,
    String id,
  ) {
    return _decodeBase64Resource(_resourcePayload(resources, id));
  }

  Uint8List? _optionalInlineBase64Decode(
    Object? value, {
    required String logicalId,
  }) {
    if (value == null) return null;
    if (value is! String) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    if (value.isEmpty) return null;
    final byteSize = _base64DecodedLength(value);
    if (byteSize > resourceBudget.maxInlineResourceBytes) {
      throw InlineResourceBudgetExceededException(
        'Inline resource $logicalId has $byteSize bytes, '
        'which exceeds ${resourceBudget.maxInlineResourceBytes}.',
      );
    }
    return _decodeBase64(value);
  }

  Uint8List _decodeBase64Resource(InlineStoredResource resource) {
    if (resource.encoding != 'base64') {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    final data = resource.base64Payload;
    if (data == null || data.isEmpty) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    final bytes = _decodeBase64(data);
    if (resource.byteSize != bytes.length) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    final expectedHash = resource.contentHash;
    if (expectedHash.isNotEmpty &&
        expectedHash != inlineResourceHashForBytes(bytes)) {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
    return bytes;
  }

  Uint8List _decodeBase64(String value) {
    try {
      return base64Decode(value);
    } on FormatException {
      throw FormatException(localizations.text('error.projectPayloadInvalid'));
    }
  }
}
