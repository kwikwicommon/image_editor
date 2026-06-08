import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'background_state.dart';

class BackgroundStateCodec {
  const BackgroundStateCodec._();

  static Map<String, dynamic> toJson(
    BackgroundState state, {
    String? customImageRef,
    bool includeLegacyCustomImage = false,
  }) {
    final normalizedState = state.normalized();
    return {
      'type': normalizedState.type.name,
      'gradientPreset': normalizedState.gradientPreset.name,
      'solidColor': normalizedState.solidColor.toARGB32(),
      'padding': normalizedState.padding,
      'cornerRadius': normalizedState.cornerRadius,
      'shadowBlur': normalizedState.shadowBlur,
      'shadowOffsetY': normalizedState.shadowOffsetY,
      'aspectRatio': normalizedState.aspectRatio.name,
      'showTitleBar': normalizedState.showTitleBar,
      'customImage': includeLegacyCustomImage &&
              normalizedState.customImageBytes != null
          ? base64Encode(normalizedState.customImageBytes!)
          : null,
      'customImageRef': customImageRef,
      'customImagePath': normalizedState.customImagePath,
      'patternPreset': normalizedState.patternPreset.name,
      'patternColor': normalizedState.patternColor.toARGB32(),
      'patternBackgroundColor': normalizedState.patternBackgroundColor
          .toARGB32(),
      'patternScale': normalizedState.patternScale,
    };
  }

  static BackgroundState fromJson(Map<String, dynamic> json) {
    return BackgroundState(
      type: BackgroundType.values.firstWhere(
        (type) => type.name == (json['type'] as String?),
        orElse: () => BackgroundType.none,
      ),
      gradientPreset: GradientPreset.values.firstWhere(
        (preset) => preset.name == (json['gradientPreset'] as String?),
        orElse: () => GradientPreset.ocean,
      ),
      solidColor: _colorFromJson(json['solidColor'], 0xFFF5F5F5),
      padding: _doubleFromJson(json['padding'], 40),
      cornerRadius: _doubleFromJson(json['cornerRadius'], 12),
      shadowBlur: _doubleFromJson(json['shadowBlur'], 20),
      shadowOffsetY: _doubleFromJson(json['shadowOffsetY'], 8),
      aspectRatio: AspectRatioPreset.values.firstWhere(
        (preset) => preset.name == (json['aspectRatio'] as String?),
        orElse: () => AspectRatioPreset.free,
      ),
      showTitleBar: json['showTitleBar'] as bool? ?? false,
      customImageBytes: _optionalBase64Decode(json['customImage'] as String?),
      customImagePath: json['customImagePath'] as String?,
      patternPreset: PatternPreset.values.firstWhere(
        (preset) => preset.name == (json['patternPreset'] as String?),
        orElse: () => PatternPreset.grid,
      ),
      patternColor: _colorFromJson(json['patternColor'], 0x20000000),
      patternBackgroundColor: _colorFromJson(
        json['patternBackgroundColor'],
        0xFFF8F9FA,
      ),
      patternScale: _doubleFromJson(json['patternScale'], 1),
    ).normalized();
  }

  static double _doubleFromJson(Object? value, double fallback) {
    if (value is! num) return fallback;
    final result = value.toDouble();
    return result.isFinite ? result : fallback;
  }

  static Color _colorFromJson(Object? value, int fallback) {
    return Color(value is num ? value.toInt() : fallback);
  }

  static Uint8List? _optionalBase64Decode(String? value) {
    if (value == null || value.isEmpty) return null;

    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}
