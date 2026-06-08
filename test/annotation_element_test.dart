import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart';

void main() {
  group('annotation hit testing', () {
    test('shape hit test respects bounds', () {
      final element = ShapeElement(
        rect: const Rect.fromLTWH(10, 10, 100, 80),
        strokeWidth: 2,
      );

      expect(element.hitTest(const Offset(10, 10)), isTrue);
      expect(element.hitTest(const Offset(200, 200)), isFalse);
    });

    test('arrow hit test accepts points close to line', () {
      final element = ArrowElement(
        startPoint: const Offset(0, 0),
        endPoint: const Offset(100, 0),
      );

      expect(element.hitTest(const Offset(50, 4)), isTrue);
      expect(element.hitTest(const Offset(50, 40)), isFalse);
    });

    test('counter hit test uses circular radius', () {
      final element = CounterElement(
        number: 1,
        position: const Offset(40, 40),
        size: 20,
      );

      expect(element.hitTest(const Offset(45, 40)), isTrue);
      expect(element.hitTest(const Offset(70, 40)), isFalse);
    });

    test('filled shape hit test accepts interior points', () {
      final element = ShapeElement(
        rect: const Rect.fromLTWH(10, 10, 100, 80),
        fillColor: Colors.blue,
      );

      expect(element.hitTest(const Offset(50, 50)), isTrue);
    });

    test('line shape hit test follows the segment instead of the bounds', () {
      final element = ShapeElement(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        shapeType: ShapeType.line,
      );

      expect(element.hitTest(const Offset(50, 54)), isTrue);
      expect(element.hitTest(const Offset(8, 92)), isFalse);
    });

    test('curved arrow hit test follows the curve', () {
      final element = ArrowElement(
        startPoint: const Offset(0, 100),
        endPoint: const Offset(100, 100),
        controlPoint: const Offset(50, 0),
        arrowType: ArrowType.curved,
      );

      expect(element.bounds.contains(const Offset(50, 0)), isTrue);
      expect(element.hitTest(const Offset(50, 50)), isTrue);
    });

    test('counter hit test respects non-circular styles', () {
      final diamond = CounterElement(
        number: 1,
        position: const Offset(40, 40),
        size: 20,
        counterStyle: CounterStyle.diamond,
      );
      final square = CounterElement(
        number: 1,
        position: const Offset(40, 40),
        size: 20,
        counterStyle: CounterStyle.square,
      );

      expect(diamond.hitTest(const Offset(48, 48)), isFalse);
      expect(square.hitTest(const Offset(48, 48)), isTrue);
    });
  });

  group('annotation JSON', () {
    test('round trips a sticker element', () {
      final element = StickerElement(
        stickerId: 'sticker',
        name: 'Sticker',
        assetPath: '',
        rect: const Rect.fromLTWH(10, 20, 30, 40),
        svgContent: '<svg viewBox="0 0 1 1"></svg>',
      );

      final restored = AnnotationElementJson.fromJson(element.toJson());

      expect(restored, isA<StickerElement>());
      expect((restored! as StickerElement).rect, element.rect);
      expect(restored.svgContent, element.svgContent);
    });

    test('invalid element JSON returns null', () {
      final restored = AnnotationElementJson.fromJson({
        'type': 'shape',
        'rect': 'invalid',
      });

      expect(restored, isNull);
    });
  });
}
