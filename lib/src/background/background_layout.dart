import 'package:flutter/material.dart';

import 'background_state.dart';

class BackgroundLayoutMetrics {
  final Size outputSize;
  final Rect windowRect;
  final Rect imageRect;
  final Rect? titleBarRect;

  const BackgroundLayoutMetrics({
    required this.outputSize,
    required this.windowRect,
    required this.imageRect,
    required this.titleBarRect,
  });

  bool get hasTitleBar => titleBarRect != null;
}

class BackgroundLayoutResolver {
  static const double titleBarHeight = 28;

  const BackgroundLayoutResolver._();

  static BackgroundLayoutMetrics resolve({
    required Size imageSize,
    required BackgroundState backgroundState,
  }) {
    final state = backgroundState.normalized();
    final safeImageSize = _safePositiveSize(imageSize);

    if (state.type == BackgroundType.none) {
      final imageRect = Offset.zero & safeImageSize;
      return BackgroundLayoutMetrics(
        outputSize: safeImageSize,
        windowRect: imageRect,
        imageRect: imageRect,
        titleBarRect: null,
      );
    }

    final padding = state.padding;
    final titleHeight = state.showTitleBar ? titleBarHeight : 0.0;
    final windowSize = Size(
      safeImageSize.width,
      safeImageSize.height + titleHeight,
    );
    final naturalSize = Size(
      windowSize.width + padding * 2,
      windowSize.height + padding * 2,
    );
    final outputSize = _expandToAspectRatio(
      naturalSize,
      state.aspectRatio.ratio,
    );

    final windowLeft = (outputSize.width - windowSize.width) / 2;
    final windowTop = (outputSize.height - windowSize.height) / 2;
    final windowRect = Rect.fromLTWH(
      windowLeft,
      windowTop,
      windowSize.width,
      windowSize.height,
    );
    final titleBarRect = state.showTitleBar
        ? Rect.fromLTWH(
            windowRect.left,
            windowRect.top,
            windowRect.width,
            titleHeight,
          )
        : null;
    final imageRect = Rect.fromLTWH(
      windowRect.left,
      windowRect.top + titleHeight,
      safeImageSize.width,
      safeImageSize.height,
    );

    return BackgroundLayoutMetrics(
      outputSize: outputSize,
      windowRect: windowRect,
      imageRect: imageRect,
      titleBarRect: titleBarRect,
    );
  }

  static Size _expandToAspectRatio(Size size, double? ratio) {
    if (ratio == null || !ratio.isFinite || ratio <= 0) return size;
    if (!_isPositiveFiniteSize(size)) return const Size(1, 1);

    final currentRatio = size.width / size.height;
    if ((currentRatio - ratio).abs() < 0.0001) return size;

    if (currentRatio < ratio) {
      return Size(size.height * ratio, size.height);
    }

    return Size(size.width, size.width / ratio);
  }

  static Size _safePositiveSize(Size size) {
    final width = size.width.isFinite && size.width > 0 ? size.width : 1.0;
    final height = size.height.isFinite && size.height > 0 ? size.height : 1.0;
    return Size(width, height);
  }

  static bool _isPositiveFiniteSize(Size size) {
    return size.width.isFinite &&
        size.height.isFinite &&
        size.width > 0 &&
        size.height > 0;
  }
}
