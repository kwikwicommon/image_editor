import 'package:flutter/material.dart';

Map<String, dynamic> offsetToJson(Offset offset) {
  return {'dx': offset.dx, 'dy': offset.dy};
}

Offset offsetFromJson(Map<String, dynamic> json) {
  return Offset(
    _finiteDoubleFromJson(json['dx'], 'dx'),
    _finiteDoubleFromJson(json['dy'], 'dy'),
  );
}

Map<String, dynamic> rectToJson(Rect rect) {
  return {
    'left': rect.left,
    'top': rect.top,
    'right': rect.right,
    'bottom': rect.bottom,
  };
}

Rect rectFromJson(Map<String, dynamic> json) {
  return Rect.fromLTRB(
    _finiteDoubleFromJson(json['left'], 'left'),
    _finiteDoubleFromJson(json['top'], 'top'),
    _finiteDoubleFromJson(json['right'], 'right'),
    _finiteDoubleFromJson(json['bottom'], 'bottom'),
  );
}

Map<String, dynamic> textStyleToJson(TextStyle? style) {
  if (style == null) return {};

  return {
    'color': style.color?.toARGB32(),
    'fontSize': style.fontSize,
    'fontWeight': style.fontWeight?.value,
    'fontStyle': style.fontStyle?.name,
    'fontFamily': style.fontFamily,
    'letterSpacing': style.letterSpacing,
  };
}

TextStyle? textStyleFromJson(Map<String, dynamic>? json) {
  if (json == null || json.isEmpty) return null;

  return TextStyle(
    color: _optionalColorFromJson(json['color']),
    fontSize: _optionalFiniteDoubleFromJson(json['fontSize']),
    fontWeight: fontWeightFromJson((json['fontWeight'] as num?)?.toInt()),
    fontStyle: FontStyle.values.firstWhere(
      (style) => style.name == json['fontStyle'],
      orElse: () => FontStyle.normal,
    ),
    fontFamily: json['fontFamily'] as String?,
    letterSpacing: _optionalFiniteDoubleFromJson(json['letterSpacing']),
  );
}

FontWeight fontWeightFromJson(int? value) {
  return FontWeight.values.firstWhere(
    (weight) => weight.value == value,
    orElse: () => FontWeight.normal,
  );
}

double _finiteDoubleFromJson(Object? value, String fieldName) {
  if (value is! num) {
    throw FormatException('Expected numeric $fieldName.');
  }
  final result = value.toDouble();
  if (!result.isFinite) {
    throw FormatException('Expected finite $fieldName.');
  }
  return result;
}

double? _optionalFiniteDoubleFromJson(Object? value) {
  if (value == null) return null;
  if (value is! num) return null;
  final result = value.toDouble();
  return result.isFinite ? result : null;
}

Color? _optionalColorFromJson(Object? value) {
  if (value == null) return null;
  if (value is! num) return null;
  return Color(value.toInt());
}
