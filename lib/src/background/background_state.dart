import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Background type
enum BackgroundType { none, gradient, solid, image, pattern }

/// Pattern presets
enum PatternPreset {
  grid,
  dots,
  diagonalLines,
  crosshatch,
  hexagons,
  waves;

  String get labelKey {
    switch (this) {
      case grid:
        return 'background.pattern.grid';
      case dots:
        return 'background.pattern.dots';
      case diagonalLines:
        return 'background.pattern.diagonalLines';
      case crosshatch:
        return 'background.pattern.crosshatch';
      case hexagons:
        return 'background.pattern.hexagons';
      case waves:
        return 'background.pattern.waves';
    }
  }

  IconData get icon {
    switch (this) {
      case grid:
        return Icons.grid_on_rounded;
      case dots:
        return Icons.blur_on_rounded;
      case diagonalLines:
        return Icons.texture_rounded;
      case crosshatch:
        return Icons.grid_4x4_rounded;
      case hexagons:
        return Icons.hexagon_outlined;
      case waves:
        return Icons.waves_rounded;
    }
  }
}

/// Gradient presets
enum GradientPreset {
  sunset,
  ocean,
  forest,
  lavender,
  peach,
  midnight,
  aurora,
  coral,
  sky,
  mint,
  rose,
  twilight;

  List<Color> get colors {
    switch (this) {
      case sunset:
        return [const Color(0xFFFF512F), const Color(0xFFDD2476)];
      case ocean:
        return [const Color(0xFF2193B0), const Color(0xFF6DD5ED)];
      case forest:
        return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
      case lavender:
        return [const Color(0xFF834D9B), const Color(0xFFD04ED6)];
      case peach:
        return [const Color(0xFFED4264), const Color(0xFFFFEDBC)];
      case midnight:
        return [const Color(0xFF232526), const Color(0xFF414345)];
      case aurora:
        return [
          const Color(0xFF7F7FD5),
          const Color(0xFF86A8E7),
          const Color(0xFF91EAE4),
        ];
      case coral:
        return [const Color(0xFFFF9A9E), const Color(0xFFFAD0C4)];
      case sky:
        return [const Color(0xFF89F7FE), const Color(0xFF66A6FF)];
      case mint:
        return [const Color(0xFF43E97B), const Color(0xFF38F9D7)];
      case rose:
        return [const Color(0xFFF5576C), const Color(0xFFF093FB)];
      case twilight:
        return [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)];
    }
  }
}

/// Aspect ratio presets
enum AspectRatioPreset {
  free,
  square,
  r16x9,
  r4x3,
  r3x2,
  twitter,
  linkedin;

  String get labelKey {
    switch (this) {
      case free:
        return 'common.free';
      case square:
        return '1:1';
      case r16x9:
        return '16:9';
      case r4x3:
        return '4:3';
      case r3x2:
        return '3:2';
      case twitter:
        return 'Twitter';
      case linkedin:
        return 'LinkedIn';
    }
  }

  double? get ratio {
    switch (this) {
      case free:
        return null;
      case square:
        return 1.0;
      case r16x9:
        return 16 / 9;
      case r4x3:
        return 4 / 3;
      case r3x2:
        return 3 / 2;
      case twitter:
        return 1200 / 675;
      case linkedin:
        return 1200 / 627;
    }
  }
}

/// Background state
class BackgroundState {
  static const double minPadding = 0;
  static const double maxPadding = 600;
  static const double minCornerRadius = 0;
  static const double maxCornerRadius = 240;
  static const double minShadowBlur = 0;
  static const double maxShadowBlur = 240;
  static const double minShadowOffsetY = -240;
  static const double maxShadowOffsetY = 240;
  static const double minPatternScale = 0.25;
  static const double maxPatternScale = 4;

  final BackgroundType type;
  final GradientPreset gradientPreset;
  final Color solidColor;
  final double padding;
  final double cornerRadius;
  final double shadowBlur;
  final double shadowOffsetY;
  final AspectRatioPreset aspectRatio;
  final bool showTitleBar;
  // Custom image background (B1)
  final Uint8List? customImageBytes;
  final String? customImagePath;
  // Pattern background (B1)
  final PatternPreset patternPreset;
  final Color patternColor;
  final Color patternBackgroundColor;
  final double patternScale;

  const BackgroundState({
    this.type = BackgroundType.none,
    this.gradientPreset = GradientPreset.ocean,
    this.solidColor = const Color(0xFFF5F5F5),
    this.padding = 40,
    this.cornerRadius = 12,
    this.shadowBlur = 20,
    this.shadowOffsetY = 8,
    this.aspectRatio = AspectRatioPreset.free,
    this.showTitleBar = false,
    this.customImageBytes,
    this.customImagePath,
    this.patternPreset = PatternPreset.grid,
    this.patternColor = const Color(0x20000000),
    this.patternBackgroundColor = const Color(0xFFF8F9FA),
    this.patternScale = 1.0,
  });

  BackgroundState copyWith({
    BackgroundType? type,
    GradientPreset? gradientPreset,
    Color? solidColor,
    double? padding,
    double? cornerRadius,
    double? shadowBlur,
    double? shadowOffsetY,
    AspectRatioPreset? aspectRatio,
    bool? showTitleBar,
    Uint8List? customImageBytes,
    String? customImagePath,
    PatternPreset? patternPreset,
    Color? patternColor,
    Color? patternBackgroundColor,
    double? patternScale,
    bool clearImage = false,
    bool clearImagePath = false,
  }) {
    return BackgroundState(
      type: type ?? this.type,
      gradientPreset: gradientPreset ?? this.gradientPreset,
      solidColor: solidColor ?? this.solidColor,
      padding: padding ?? this.padding,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      showTitleBar: showTitleBar ?? this.showTitleBar,
      customImageBytes: clearImage
          ? null
          : (customImageBytes ?? this.customImageBytes),
      customImagePath: clearImage || clearImagePath
          ? null
          : (customImagePath ?? this.customImagePath),
      patternPreset: patternPreset ?? this.patternPreset,
      patternColor: patternColor ?? this.patternColor,
      patternBackgroundColor:
          patternBackgroundColor ?? this.patternBackgroundColor,
      patternScale: patternScale ?? this.patternScale,
    ).normalized();
  }

  BackgroundState normalized() {
    return BackgroundState(
      type: type,
      gradientPreset: gradientPreset,
      solidColor: solidColor,
      padding: _finiteClamped(padding, 40, minPadding, maxPadding),
      cornerRadius: _finiteClamped(
        cornerRadius,
        12,
        minCornerRadius,
        maxCornerRadius,
      ),
      shadowBlur: _finiteClamped(shadowBlur, 20, minShadowBlur, maxShadowBlur),
      shadowOffsetY: _finiteClamped(
        shadowOffsetY,
        8,
        minShadowOffsetY,
        maxShadowOffsetY,
      ),
      aspectRatio: aspectRatio,
      showTitleBar: showTitleBar,
      customImageBytes: _detachedBytes(customImageBytes),
      customImagePath: _normalizedPath(customImagePath),
      patternPreset: patternPreset,
      patternColor: patternColor,
      patternBackgroundColor: patternBackgroundColor,
      patternScale: _finiteClamped(
        patternScale,
        1,
        minPatternScale,
        maxPatternScale,
      ),
    );
  }

  static double _finiteClamped(
    double value,
    double fallback,
    double min,
    double max,
  ) {
    final finiteValue = value.isFinite ? value : fallback;
    return finiteValue.clamp(min, max).toDouble();
  }

  static String? _normalizedPath(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Uint8List? _detachedBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    return Uint8List.fromList(bytes);
  }
}
