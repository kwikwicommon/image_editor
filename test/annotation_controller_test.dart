import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart';

void main() {
  test('listeners observe element edits, selection, and undo', () {
    final controller = AnnotationController();
    addTearDown(controller.dispose);
    final shape = ShapeElement(rect: const Rect.fromLTWH(0, 0, 20, 20));
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.addElement(shape);
    expect(notifications, greaterThan(0));
    notifications = 0;
    controller.selectElement(shape.id);
    expect(controller.selectedElementIds, contains(shape.id));
    expect(notifications, greaterThan(0));
    notifications = 0;
    controller.deleteSelected();
    expect(controller.elements, isEmpty);
    expect(notifications, greaterThan(0));
    notifications = 0;
    controller.undo();
    expect(controller.elements.single.id, shape.id);
    expect(notifications, greaterThan(0));
  });

  test('AnnotationController undo and redo restore element history', () {
    final controller = AnnotationController();
    final first = ShapeElement(rect: const Rect.fromLTWH(0, 0, 10, 10));
    final second = ShapeElement(rect: const Rect.fromLTWH(20, 20, 10, 10));

    controller.addElement(first);
    controller.addElement(second);

    expect(controller.elements.length, 2);
    controller.undo();
    expect(controller.elements.length, 1);
    controller.redo();
    expect(controller.elements.length, 2);
  });

  test('AnnotationController computes alignment guides', () {
    final controller = AnnotationController();
    final target = ShapeElement(rect: const Rect.fromLTWH(10, 10, 40, 40));
    final dragged = ShapeElement(rect: const Rect.fromLTWH(52, 10, 20, 20));

    controller.addElement(target);
    controller.updateAlignmentGuides(dragged);

    expect(controller.alignmentGuides, isNotEmpty);
    expect(
      controller.alignmentGuides.any((guide) => guide.isHorizontal),
      isTrue,
    );
  });

  test('AnnotationController undo restores cropped image state', () {
    final controller = AnnotationController();
    final originalImage = Uint8List.fromList([1, 2, 3]);
    final croppedImage = Uint8List.fromList([4, 5, 6]);
    controller.loadImage(originalImage, const Size(100, 80));
    controller.addElement(
      ShapeElement(rect: const Rect.fromLTWH(20, 20, 30, 30)),
    );

    controller.applyCrop(
      imageBytes: croppedImage,
      cropRect: const Rect.fromLTWH(10, 10, 40, 30),
    );

    expect(controller.backgroundImage.value, same(croppedImage));
    expect(controller.imageSize.value, const Size(40, 30));

    controller.undo();

    expect(controller.backgroundImage.value, same(originalImage));
    expect(controller.imageSize.value, const Size(100, 80));
    expect(
      (controller.elements.single as ShapeElement).rect.topLeft,
      const Offset(20, 20),
    );
  });

  test('AnnotationController ignores updates for missing elements', () {
    final controller = AnnotationController();

    controller.updateElement(
      'missing',
      ShapeElement(rect: const Rect.fromLTWH(0, 0, 10, 10)),
    );

    expect(controller.undoStack, isEmpty);
  });
}
