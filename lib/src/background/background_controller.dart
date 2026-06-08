import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'background_state.dart';

class BackgroundController extends GetxController {
  final state = const BackgroundState().obs;

  void setType(BackgroundType type) {
    state.value = state.value.copyWith(type: type);
  }

  void setGradientPreset(GradientPreset preset) {
    state.value = state.value.copyWith(
      gradientPreset: preset,
      type: BackgroundType.gradient,
    );
  }

  void setSolidColor(Color color) {
    state.value = state.value.copyWith(
      solidColor: color,
      type: BackgroundType.solid,
    );
  }

  void setPadding(double padding) {
    state.value = state.value.copyWith(padding: padding);
  }

  void setCornerRadius(double radius) {
    state.value = state.value.copyWith(cornerRadius: radius);
  }

  void setShadowBlur(double blur) {
    state.value = state.value.copyWith(shadowBlur: blur);
  }

  void setShadowOffsetY(double offsetY) {
    state.value = state.value.copyWith(shadowOffsetY: offsetY);
  }

  void setAspectRatio(AspectRatioPreset ratio) {
    state.value = state.value.copyWith(aspectRatio: ratio);
  }

  void setShowTitleBar(bool show) {
    state.value = state.value.copyWith(showTitleBar: show);
  }

  void setCustomImage(Uint8List bytes, {String? path}) {
    if (bytes.isEmpty) {
      clearCustomImage();
      return;
    }
    state.value = state.value.copyWith(
      type: BackgroundType.image,
      customImageBytes: Uint8List.fromList(bytes),
      customImagePath: path,
      clearImagePath: path == null,
    );
  }

  void clearCustomImage() {
    final nextState = state.value.copyWith(clearImage: true);
    state.value = nextState.type == BackgroundType.image
        ? nextState.copyWith(type: BackgroundType.none)
        : nextState;
  }

  void setPatternPreset(PatternPreset preset) {
    state.value = state.value.copyWith(
      type: BackgroundType.pattern,
      patternPreset: preset,
    );
  }

  void setPatternColor(Color color) {
    state.value = state.value.copyWith(patternColor: color);
  }

  void setPatternBackgroundColor(Color color) {
    state.value = state.value.copyWith(patternBackgroundColor: color);
  }

  void setPatternScale(double scale) {
    state.value = state.value.copyWith(patternScale: scale);
  }

  void replace(BackgroundState backgroundState) {
    state.value = backgroundState.normalized();
  }
}
