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

class ExternalSourceRef {
  final String path;
  final String? fingerprint;
  final int? fileSize;
  final DateTime? modifiedAt;

  const ExternalSourceRef({
    required this.path,
    this.fingerprint,
    this.fileSize,
    this.modifiedAt,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (fileSize != null) 'fileSize': fileSize,
    if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
  };

  factory ExternalSourceRef.fromJson(Map<String, dynamic> json) {
    return ExternalSourceRef(
      path: json['path'] as String? ?? '',
      fingerprint: json['fingerprint'] as String?,
      fileSize: json['fileSize'] as int?,
      modifiedAt: json['modifiedAt'] is String
          ? DateTime.tryParse(json['modifiedAt'] as String)
          : null,
    );
  }
}

class ProjectFile {
  static const String fileExtension = '.gcs';
  static const int currentVersion = 2;

  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectSnapshot snapshot;
  final ExternalSourceRef? externalSourceRef;

  ProjectFile({
    this.version = currentVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    required this.snapshot,
    this.externalSourceRef,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

typedef ProjectMigration = Map<String, dynamic> Function(
  Map<String, dynamic> json,
);

class ProjectSchemaMigrator {
  static const Map<int, ProjectMigration> _migrations = {
    1: _migrateV1ToV2,
  };

  static Map<String, dynamic> migrate(
    Map<String, dynamic> json, {
    required int fromVersion,
    required int toVersion,
  }) {
    var current = Map<String, dynamic>.from(json);
    for (var v = fromVersion; v < toVersion; v++) {
      final migration = _migrations[v];
      if (migration == null) break;
      current = migration(current);
      current['projectFileVersion'] = v + 1;
    }
    return current;
  }

  static Map<String, dynamic> _migrateV1ToV2(Map<String, dynamic> json) {
    final migrated = Map<String, dynamic>.from(json);
    migrated['projectFileVersion'] = 2;
    if (!migrated.containsKey('externalSourceRef')) {
      final imageRef = migrated['imageRef'];
      if (imageRef is Map && imageRef['path'] != null) {
        migrated['externalSourceRef'] = {'path': imageRef['path']};
      }
    }
    return migrated;
  }
}
