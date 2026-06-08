import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart';

void main() {
  testWidgets('annotation elements render golden output', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          child: CustomPaint(
            size: const Size(160, 100),
            painter: AnnotationCanvasPainter(
              elements: [
                ArrowElement(
                  startPoint: const Offset(12, 20),
                  endPoint: const Offset(120, 20),
                ),
                ShapeElement(rect: const Rect.fromLTWH(24, 40, 60, 36)),
                CounterElement(number: 1, position: const Offset(120, 64)),
              ],
              selectionColor: const Color(0xFF6366F1),
              stickerRenderCache: StickerRenderCache(),
              localizations: const DefaultImageEditorLocalizations(),
              showSelectionHandles: false,
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/annotation_elements.png'),
    );
  });
}
