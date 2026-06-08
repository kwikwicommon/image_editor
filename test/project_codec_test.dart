import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_editor/image_editor.dart';

void main() {
  test('ProjectCodec round trips project snapshots', () {
    const codec = ProjectCodec();
    final file = ProjectFile(
      snapshot: ProjectSnapshot(
        elements: [ShapeElement(rect: const Rect.fromLTWH(0, 0, 20, 20))],
        backgroundState: const BackgroundState(type: BackgroundType.solid),
        imageRef: const ProjectImageRef(id: 'source', size: Size(20, 20)),
      ),
    );

    final restored = codec.decodeString(codec.encodeString(file));

    expect(restored.snapshot.elements, hasLength(1));
    expect(restored.snapshot.backgroundState.type, BackgroundType.solid);
    expect(restored.snapshot.imageRef.id, 'source');
  });

  test('ProjectCodec writes manifest resources with deduped refs', () {
    const codec = ProjectCodec();
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final file = ProjectFile(
      snapshot: ProjectSnapshot(
        elements: const [],
        backgroundState: BackgroundState(
          type: BackgroundType.image,
          customImageBytes: bytes,
        ),
        imageRef: ProjectImageRef(
          id: 'source',
          bytes: bytes,
          size: const Size(2, 2),
        ),
      ),
    );

    final json = codec.encode(file);
    final resources = json['resources'] as Map<String, dynamic>;
    final backgroundImageRef = json['backgroundImageRef'] as String;
    final backgroundSettings =
        json['backgroundSettings'] as Map<String, dynamic>;
    final resource = resources[backgroundImageRef] as Map<String, dynamic>;

    expect(json['resourceMode'], 'manifest');
    expect(resources, hasLength(1));
    expect(backgroundSettings['customImageRef'], backgroundImageRef);
    expect(backgroundSettings['customImage'], isNull);
    expect(resource['refCount'], 2);
  });

  test('ProjectCodec decodes main app manifest project shape', () {
    const codec = ProjectCodec();
    final bytes = Uint8List.fromList([9, 8, 7]);
    final data = base64Encode(bytes);
    const resourceId = 'res_backgroundImage_test';

    final restored = codec.decode({
      'projectFileVersion': ProjectFile.currentVersion,
      'version': '1.0',
      'resourceMode': 'manifest',
      'resources': {
        resourceId: {
          'id': resourceId,
          'kind': 'backgroundImage',
          'storage': 'manifest',
          'encoding': 'base64',
          'byteSize': bytes.length,
          'contentHash': inlineResourceHashForBytes(bytes),
          'refCount': 2,
          'data': data,
        },
      },
      'canvasSize': {'width': 3, 'height': 1},
      'backgroundImageRef': resourceId,
      'elements': const [],
      'backgroundSettings': {'type': 'image', 'customImageRef': resourceId},
    });

    expect(restored.snapshot.imageRef.bytes, orderedEquals(bytes));
    expect(restored.snapshot.imageRef.size, const Size(3, 1));
    expect(restored.snapshot.backgroundState.type, BackgroundType.image);
    expect(
      restored.snapshot.backgroundState.customImageBytes,
      orderedEquals(bytes),
    );
  });

  test('ProjectCodec rejects unsupported versions', () {
    const codec = ProjectCodec();

    expect(
      () => codec.decode({
        'projectFileVersion': ProjectFile.currentVersion + 1,
        'imageRef': {'id': 'source'},
      }),
      throwsA(isA<UnsupportedProjectVersionException>()),
    );
  });

  test('ProjectCodec rejects manifest resources with mismatched hash', () {
    const codec = ProjectCodec();
    final bytes = Uint8List.fromList([1, 2, 3]);
    const resourceId = 'res_backgroundImage_bad_hash';

    expect(
      () => codec.decode({
        'projectFileVersion': ProjectFile.currentVersion,
        'resources': {
          resourceId: {
            'id': resourceId,
            'kind': 'backgroundImage',
            'storage': 'manifest',
            'encoding': 'base64',
            'byteSize': bytes.length,
            'contentHash': 'not-the-resource-hash',
            'data': base64Encode(bytes),
          },
        },
        'backgroundImageRef': resourceId,
        'imageRef': {
          'resourceId': resourceId,
          'size': {'width': 3, 'height': 1},
        },
      }),
      throwsFormatException,
    );
  });

  test('ProjectSnapshot detaches mutable image bytes', () {
    final sourceBytes = Uint8List.fromList([1, 2, 3]);
    final customBytes = Uint8List.fromList([4, 5, 6]);
    final snapshot = ProjectSnapshot(
      elements: const [],
      backgroundState: BackgroundState(
        type: BackgroundType.image,
        customImageBytes: customBytes,
      ),
      imageRef: ProjectImageRef(
        id: 'source',
        bytes: sourceBytes,
        size: const Size(3, 1),
      ),
    );

    sourceBytes[0] = 9;
    customBytes[0] = 9;

    expect(snapshot.imageRef.bytes, orderedEquals([1, 2, 3]));
    expect(snapshot.backgroundState.customImageBytes, orderedEquals([4, 5, 6]));
  });
}
