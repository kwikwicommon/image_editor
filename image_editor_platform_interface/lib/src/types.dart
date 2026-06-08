class ImageEditorCapabilities {
  static const unsupported = ImageEditorCapabilities(
    platform: 'unsupported',
    canCopyPngToClipboard: false,
  );

  final String platform;
  final bool canCopyPngToClipboard;
  final Map<String, Object?> extra;

  const ImageEditorCapabilities({
    required this.platform,
    required this.canCopyPngToClipboard,
    this.extra = const <String, Object?>{},
  });

  factory ImageEditorCapabilities.fromNative(Object? value) {
    final map = imageEditorNativeMap(value);
    if (map.isEmpty) {
      return unsupported;
    }
    return ImageEditorCapabilities(
      platform: _readString(map, 'platform') ?? 'unknown',
      canCopyPngToClipboard:
          _readBool(map, 'canCopyPngToClipboard') ??
          _readBool(map, 'supportsClipboard') ??
          false,
      extra: Map<String, Object?>.unmodifiable(map),
    );
  }
}

class ImageEditorClipboardResult {
  final bool isSuccess;
  final String? code;
  final String? message;
  final String? recoverySuggestion;
  final Object? details;

  const ImageEditorClipboardResult.success({
    this.message,
    this.details,
  }) : isSuccess = true,
       code = null,
       recoverySuggestion = null;

  const ImageEditorClipboardResult.failure({
    required this.code,
    required this.message,
    this.recoverySuggestion,
    this.details,
  }) : isSuccess = false;

  factory ImageEditorClipboardResult.fromNative(Object? value) {
    final map = imageEditorNativeMap(value);
    if (map.isEmpty) {
      return const ImageEditorClipboardResult.failure(
        code: 'invalidResponse',
        message: 'Native clipboard copy returned an invalid response.',
      );
    }
    final success =
        _readBool(map, 'success') ?? (_readString(map, 'status') == 'success');
    if (success) {
      return ImageEditorClipboardResult.success(
        message: _readString(map, 'message'),
        details: map['details'] ?? map['payload'],
      );
    }
    return ImageEditorClipboardResult.failure(
      code: _readString(map, 'code') ?? _readString(map, 'status') ?? 'failed',
      message: _readString(map, 'message') ?? 'Native clipboard copy failed.',
      recoverySuggestion: _readString(map, 'recoverySuggestion'),
      details: map['details'] ?? map['payload'],
    );
  }
}

Map<String, Object?> imageEditorNativeMap(Object? value) {
  if (value is Map) {
    return value.map<String, Object?>(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  return const <String, Object?>{};
}

String? _readString(Map<String, Object?> map, String key) {
  final value = map[key];
  return value is String ? value : null;
}

bool? _readBool(Map<String, Object?> map, String key) {
  final value = map[key];
  return value is bool ? value : null;
}
