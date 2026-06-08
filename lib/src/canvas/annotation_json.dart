import 'package:flutter/material.dart';

import '../core/serialization_utils.dart';
import 'annotation_element.dart';

class AnnotationElementJson {
  const AnnotationElementJson._();

  static AnnotationElement? fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'] as String?;
      switch (type) {
        case 'arrow':
          return ArrowElement(
            id: json['id'] as String?,
            startPoint: offsetFromJson(_jsonMap(json['startPoint'])),
            endPoint: offsetFromJson(_jsonMap(json['endPoint'])),
            controlPoint: json['controlPoint'] != null
                ? offsetFromJson(_jsonMap(json['controlPoint']))
                : null,
            color: _colorFromJson(json['color'], Colors.red),
            strokeWidth: _strokeWidthFromJson(json['strokeWidth']),
            headStyle: ArrowHeadStyle.values.firstWhere(
              (style) => style.name == json['headStyle'],
              orElse: () => ArrowHeadStyle.filled,
            ),
            arrowType: ArrowType.values.firstWhere(
              (arrowType) => arrowType.name == json['arrowType'],
              orElse: () => ArrowType.straight,
            ),
            isDashed: json['isDashed'] as bool? ?? false,
            rotation: _rotationFromJson(json['rotation']),
            scale: _scaleFromJson(json['scale']),
            zIndex: _intFromJson(json['zIndex'], 0),
            isLocked: json['isLocked'] as bool? ?? false,
            isVisible: json['isVisible'] as bool? ?? true,
          );
        case 'shape':
          return ShapeElement(
            id: json['id'] as String?,
            rect: rectFromJson(_jsonMap(json['rect'])),
            strokeColor: _colorFromJson(json['strokeColor'], Colors.red),
            fillColor: _optionalColorFromJson(json['fillColor']),
            strokeWidth: _strokeWidthFromJson(json['strokeWidth']),
            cornerRadius: _clampedDoubleFromJson(
              json['cornerRadius'],
              fallback: 0,
              min: 0,
              max: 4096,
            ),
            shapeType: ShapeType.values.firstWhere(
              (shapeType) => shapeType.name == json['shapeType'],
              orElse: () => ShapeType.rectangle,
            ),
            isDashed: json['isDashed'] as bool? ?? false,
            rotation: _rotationFromJson(json['rotation']),
            scale: _scaleFromJson(json['scale']),
            zIndex: _intFromJson(json['zIndex'], 0),
            isLocked: json['isLocked'] as bool? ?? false,
            isVisible: json['isVisible'] as bool? ?? true,
          );
        case 'text':
          return TextAnnotation(
            id: json['id'] as String?,
            text: json['text'] as String? ?? '',
            position: _elementPositionFromJson(json),
            textColor: _colorFromJson(json['textColor'], Colors.white),
            fontSize: _fontSizeFromJson(json['fontSize']),
            fontWeight: fontWeightFromJson(
              _intFromJson(json['fontWeight'], 400),
            ),
            backgroundColor: _optionalColorFromJson(json['backgroundColor']),
            style: textStyleFromJson(_optionalJsonMap(json['style'])),
            maxWidth: _clampedDoubleFromJson(
              json['maxWidth'],
              fallback: 300,
              min: 1,
              max: 10000,
            ),
            rotation: _rotationFromJson(json['rotation']),
            scale: _scaleFromJson(json['scale']),
            zIndex: _intFromJson(json['zIndex'], 0),
            isLocked: json['isLocked'] as bool? ?? false,
            isVisible: json['isVisible'] as bool? ?? true,
          );
        case 'freedraw':
          final pointsJson = json['points'];
          final points = pointsJson is List<dynamic>
              ? pointsJson.map((point) {
                  return offsetFromJson(_jsonMap(point));
                }).toList()
              : const <Offset>[];
          return FreeDrawElement(
            id: json['id'] as String?,
            points: points,
            color: _colorFromJson(json['color'], Colors.red),
            strokeWidth: _strokeWidthFromJson(json['strokeWidth']),
            isHighlighter: json['isHighlighter'] as bool? ?? false,
            rotation: _rotationFromJson(json['rotation']),
            scale: _scaleFromJson(json['scale']),
            zIndex: _intFromJson(json['zIndex'], 0),
            isLocked: json['isLocked'] as bool? ?? false,
            isVisible: json['isVisible'] as bool? ?? true,
          );
        case 'blur':
          return BlurElement(
            id: json['id'] as String?,
            rect: rectFromJson(_jsonMap(json['rect'])),
            blurMode: BlurMode.values.firstWhere(
              (mode) => mode.name == json['blurMode'],
              orElse: () => BlurMode.mosaic,
            ),
            intensity: _clampedDoubleFromJson(
              json['intensity'],
              fallback: 10,
              min: 1,
              max: 80,
            ),
            rotation: _rotationFromJson(json['rotation']),
            scale: _scaleFromJson(json['scale']),
            zIndex: _intFromJson(json['zIndex'], 0),
            isLocked: json['isLocked'] as bool? ?? false,
            isVisible: json['isVisible'] as bool? ?? true,
          );
        case 'counter':
          return CounterElement(
            id: json['id'] as String?,
            number: _clampedIntFromJson(
              json['number'],
              fallback: 1,
              min: 1,
              max: 999999,
            ),
            position: _elementPositionFromJson(json),
            color: _colorFromJson(json['color'], Colors.red),
            size: _clampedDoubleFromJson(
              json['size'],
              fallback: 28,
              min: 1,
              max: 4096,
            ),
            counterStyle: CounterStyle.values.firstWhere(
              (style) => style.name == json['counterStyle'],
              orElse: () => CounterStyle.circle,
            ),
            rotation: _rotationFromJson(json['rotation']),
            scale: _scaleFromJson(json['scale']),
            zIndex: _intFromJson(json['zIndex'], 0),
            isLocked: json['isLocked'] as bool? ?? false,
            isVisible: json['isVisible'] as bool? ?? true,
          );
        case 'sticker':
          return StickerElement(
            id: json['id'] as String?,
            stickerId: json['stickerId'] as String?,
            name: json['name'] as String?,
            assetPath: json['assetPath'] as String? ?? '',
            rect: rectFromJson(_jsonMap(json['rect'])),
            format: StickerFormat.values.firstWhere(
              (format) => format.name == json['format'],
              orElse: () => StickerFormat.svg,
            ),
            tintColor: _optionalColorFromJson(json['tintColor']),
            svgContent: json['svgContent'] as String?,
            dataBase64: json['dataBase64'] as String?,
            resourceId: json['resourceId'] as String?,
            resourceHash: json['resourceHash'] as String?,
            isRecolorable: json['isRecolorable'] as bool? ?? true,
            isFlippedH: json['isFlippedH'] as bool? ?? false,
            isFlippedV: json['isFlippedV'] as bool? ?? false,
            rotation: _rotationFromJson(json['rotation']),
            scale: _scaleFromJson(json['scale']),
            zIndex: _intFromJson(json['zIndex'], 0),
            isLocked: json['isLocked'] as bool? ?? false,
            isVisible: json['isVisible'] as bool? ?? true,
          );
        default:
          return null;
      }
    } on Object {
      return null;
    }
  }

  static Map<String, dynamic> toJson(AnnotationElement element) {
    if (element is ArrowElement) return _arrowToJson(element);
    if (element is ShapeElement) return _shapeToJson(element);
    if (element is TextAnnotation) return _textToJson(element);
    if (element is FreeDrawElement) return _freeDrawToJson(element);
    if (element is BlurElement) return _blurToJson(element);
    if (element is CounterElement) return _counterToJson(element);
    if (element is StickerElement) return _stickerToJson(element);
    throw UnsupportedError('Unsupported annotation element type');
  }

  static Map<String, dynamic> _arrowToJson(ArrowElement element) => {
    'type': 'arrow',
    ...baseElementToJson(element),
    'startPoint': offsetToJson(element.startPoint),
    'endPoint': offsetToJson(element.endPoint),
    'controlPoint': element.controlPoint != null
        ? offsetToJson(element.controlPoint!)
        : null,
    'color': element.color.toARGB32(),
    'strokeWidth': element.strokeWidth,
    'headStyle': element.headStyle.name,
    'arrowType': element.arrowType.name,
    'isDashed': element.isDashed,
  };

  static Map<String, dynamic> _shapeToJson(ShapeElement element) => {
    'type': 'shape',
    ...baseElementToJson(element),
    'rect': rectToJson(element.rect),
    'strokeColor': element.strokeColor.toARGB32(),
    'fillColor': element.fillColor?.toARGB32(),
    'strokeWidth': element.strokeWidth,
    'cornerRadius': element.cornerRadius,
    'shapeType': element.shapeType.name,
    'isDashed': element.isDashed,
  };

  static Map<String, dynamic> _textToJson(TextAnnotation element) => {
    'type': 'text',
    ...baseElementToJson(element),
    'text': element.text,
    'position': offsetToJson(element.position),
    'textColor': element.textColor.toARGB32(),
    'fontSize': element.fontSize,
    'fontWeight': element.fontWeight.value,
    'backgroundColor': element.backgroundColor?.toARGB32(),
    'style': textStyleToJson(element.style),
    'maxWidth': element.maxWidth,
  };

  static Map<String, dynamic> _freeDrawToJson(FreeDrawElement element) => {
    'type': 'freedraw',
    ...baseElementToJson(element),
    'points': element.points.map(offsetToJson).toList(),
    'color': element.color.toARGB32(),
    'strokeWidth': element.strokeWidth,
    'isHighlighter': element.isHighlighter,
  };

  static Map<String, dynamic> _blurToJson(BlurElement element) => {
    'type': 'blur',
    ...baseElementToJson(element),
    'rect': rectToJson(element.rect),
    'blurMode': element.blurMode.name,
    'intensity': element.intensity,
  };

  static Map<String, dynamic> _counterToJson(CounterElement element) => {
    'type': 'counter',
    ...baseElementToJson(element),
    'number': element.number,
    'position': offsetToJson(element.position),
    'color': element.color.toARGB32(),
    'size': element.size,
    'counterStyle': element.counterStyle.name,
  };

  static Map<String, dynamic> _stickerToJson(StickerElement element) => {
    'type': 'sticker',
    ...baseElementToJson(element),
    'stickerId': element.stickerId,
    'name': element.name,
    'assetPath': element.assetPath,
    'format': element.format.name,
    'rect': rectToJson(element.rect),
    'tintColor': element.tintColor?.toARGB32(),
    'svgContent': element.svgContent,
    'dataBase64': element.dataBase64,
    'resourceId': element.resourceId,
    'resourceHash': element.resourceHash,
    'isRecolorable': element.isRecolorable,
    'isFlippedH': element.isFlippedH,
    'isFlippedV': element.isFlippedV,
  };

  static Map<String, dynamic> _jsonMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return Map<String, dynamic>.from(value);
  }

  static Map<String, dynamic>? _optionalJsonMap(Object? value) {
    if (value == null) return null;
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  static Offset _elementPositionFromJson(Map<String, dynamic> json) {
    final positionJson = json['position'];
    return positionJson != null
        ? offsetFromJson(_jsonMap(positionJson))
        : Offset.zero;
  }

  static double _rotationFromJson(Object? value) {
    return _doubleFromJson(value, 0).clamp(-360.0, 360.0).toDouble();
  }

  static double _scaleFromJson(Object? value) {
    return _doubleFromJson(value, 1).clamp(0.01, 100.0).toDouble();
  }

  static double _strokeWidthFromJson(Object? value) {
    return _clampedDoubleFromJson(value, fallback: 2, min: 1, max: 64);
  }

  static double _fontSizeFromJson(Object? value) {
    return _clampedDoubleFromJson(value, fallback: 16, min: 6, max: 256);
  }

  static double _clampedDoubleFromJson(
    Object? value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    return _doubleFromJson(value, fallback).clamp(min, max).toDouble();
  }

  static double _doubleFromJson(Object? value, double fallback) {
    final parsed = value is num ? value.toDouble() : fallback;
    return parsed.isFinite ? parsed : fallback;
  }

  static int _intFromJson(Object? value, int fallback) {
    if (value is! num || !value.toDouble().isFinite) return fallback;
    return value.toInt();
  }

  static int _clampedIntFromJson(
    Object? value, {
    required int fallback,
    required int min,
    required int max,
  }) {
    return _intFromJson(value, fallback).clamp(min, max).toInt();
  }

  static Color _colorFromJson(Object? value, Color fallback) {
    if (value is! num || !value.toDouble().isFinite) return fallback;
    return Color(value.toInt());
  }

  static Color? _optionalColorFromJson(Object? value) {
    if (value is! num || !value.toDouble().isFinite) return null;
    return Color(value.toInt());
  }
}
