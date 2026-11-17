import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart';

void main() {
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

  Uint8List pngBytes() => Uint8List.fromList(base64Decode(pngBase64));

  testWidgets('AnnotationCanvas supports basic tap interaction', (
    tester,
  ) async {
    final controller = AnnotationController();
    controller.loadProject(
      imageBytes: pngBytes(),
      imageSize: const Size(100, 100),
      elements: [ShapeElement(rect: const Rect.fromLTWH(10, 10, 40, 40))],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 100,
            child: AnnotationCanvas(
              imageBytes: pngBytes(),
              imageSize: const Size(100, 100),
              controller: controller,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getTopLeft(find.byType(AnnotationCanvas)) + const Offset(10, 10),
    );
    await tester.pump();

    expect(controller.selectedElementIds, isNotEmpty);
  });

  testWidgets('ImageEditorView exposes save lifecycle callback', (
    tester,
  ) async {
    ProjectSnapshot? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageEditorView(
            imageBytes: pngBytes(),
            imageSize: const Size(100, 100),
            onSave: (snapshot) => saved = snapshot,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.imageRef.size, const Size(100, 100));
  });
}
