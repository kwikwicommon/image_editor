import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../background/background_state.dart';
import '../canvas/annotation_element.dart';

class UnsupportedProjectVersionException implements Exception {
  final String message;

  const UnsupportedProjectVersionException(this.message);

  @override
  String toString() => message;
}

class ProjectImageRef {
  final String id;
  final String? path;
  final Uint8List? bytes;
  final Size? size;

  const ProjectImageRef({required this.id, this.path, this.bytes, this.size});

  ProjectImageRef detached() {
    final currentBytes = bytes;
    return ProjectImageRef(
      id: id,
      path: path,
      bytes: currentBytes == null ? null : Uint8List.fromList(currentBytes),
      size: size,
    );
  }
}

class ProjectSnapshot {
  final List<AnnotationElement> elements;
  final BackgroundState backgroundState;
  final ProjectImageRef imageRef;

  ProjectSnapshot({
    required List<AnnotationElement> elements,
    required BackgroundState backgroundState,
    required ProjectImageRef imageRef,
  }) : elements = List.unmodifiable(elements),
       backgroundState = backgroundState.normalized(),
       imageRef = imageRef.detached();
}

class ProjectFile {
  static const String fileExtension = '.gcs';
  static const int currentVersion = 1;

  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectSnapshot snapshot;

  ProjectFile({
    this.version = currentVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.snapshot,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}
