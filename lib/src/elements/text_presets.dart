import 'package:flutter/material.dart';

/// Text style presets for quick annotation
enum TextPreset {
  normal,
  pill,
  bold,
  code,
  handwriting,
  title,
  comment;

  String get labelKey {
    switch (this) {
      case normal:
        return 'annotate.textPreset.normal';
      case pill:
        return 'annotate.textPreset.pill';
      case bold:
        return 'annotate.textPreset.bold';
      case code:
        return 'annotate.textPreset.code';
      case handwriting:
        return 'annotate.textPreset.handwriting';
      case title:
        return 'annotate.textPreset.title';
      case comment:
        return 'annotate.textPreset.comment';
    }
  }

  TextStyle textStyle(Color color) {
    switch (this) {
      case normal:
        return TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        );
      case pill:
        return TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
      case bold:
        return TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        );
      case code:
        return TextStyle(
          color: const Color(0xFFE06C75),
          fontSize: 14,
          fontWeight: FontWeight.w400,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        );
      case handwriting:
        return TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
        );
      case title:
        return TextStyle(
          color: color,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        );
      case comment:
        return TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
        );
    }
  }

  Color? backgroundColor(Color color) {
    switch (this) {
      case pill:
        return color;
      case code:
        return const Color(0xFF282C34);
      default:
        return null;
    }
  }

  double get defaultFontSize {
    switch (this) {
      case normal:
        return 16;
      case pill:
        return 14;
      case bold:
        return 18;
      case code:
        return 14;
      case handwriting:
        return 18;
      case title:
        return 28;
      case comment:
        return 12;
    }
  }
}
