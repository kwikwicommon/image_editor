import 'package:flutter/material.dart';

class ImageBackgroundPlaceholderPainter extends CustomPainter {
  final Color? backgroundColor;
  final Color? stripeColor;
  final Color? iconColor;

  const ImageBackgroundPlaceholderPainter({
    this.backgroundColor,
    this.stripeColor,
    this.iconColor,
  });

  static void paintPlaceholder(
    Canvas canvas,
    Size size, {
    Color? backgroundColor,
    Color? stripeColor,
    Color? iconColor,
  }) {
    if (!_isPositiveFiniteSize(size)) return;

    final rect = Offset.zero & size;
    final backgroundPaint = Paint()
      ..color = backgroundColor ?? const Color(0xFFE5E7EB);
    canvas.drawRect(rect, backgroundPaint);

    final stripePaint = Paint()
      ..color = stripeColor ?? const Color(0xFFD1D5DB)
      ..strokeWidth = 2;
    const spacing = 18.0;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripePaint,
      );
    }

    final iconSize = size.shortestSide.clamp(28.0, 56.0).toDouble();
    final iconRect = Rect.fromCenter(
      center: rect.center,
      width: iconSize,
      height: iconSize,
    );
    final iconPaint = Paint()
      ..color = iconColor ?? const Color(0xFF6B7280)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(iconRect, const Radius.circular(8)),
      iconPaint,
    );
    canvas.drawCircle(
      Offset(iconRect.left + iconSize * 0.32, iconRect.top + iconSize * 0.32),
      iconSize * 0.08,
      iconPaint,
    );

    final mountainPath = Path()
      ..moveTo(
        iconRect.left + iconSize * 0.16,
        iconRect.bottom - iconSize * 0.2,
      )
      ..lineTo(iconRect.left + iconSize * 0.42, iconRect.top + iconSize * 0.52)
      ..lineTo(iconRect.left + iconSize * 0.58, iconRect.top + iconSize * 0.68)
      ..lineTo(iconRect.left + iconSize * 0.72, iconRect.top + iconSize * 0.44)
      ..lineTo(
        iconRect.right - iconSize * 0.14,
        iconRect.bottom - iconSize * 0.2,
      );
    canvas.drawPath(mountainPath, iconPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintPlaceholder(
      canvas,
      size,
      backgroundColor: backgroundColor,
      stripeColor: stripeColor,
      iconColor: iconColor,
    );
  }

  @override
  bool shouldRepaint(covariant ImageBackgroundPlaceholderPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        stripeColor != oldDelegate.stripeColor ||
        iconColor != oldDelegate.iconColor;
  }

  static bool _isPositiveFiniteSize(Size size) {
    return size.width.isFinite &&
        size.height.isFinite &&
        size.width > 0 &&
        size.height > 0;
  }
}
