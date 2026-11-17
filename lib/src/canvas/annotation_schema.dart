/// Schema versioning for annotation element serialization.
/// Ensures unknown fields are preserved during round-trip and
/// unknown element types are surfaced as errors rather than silently dropped.
class AnnotationSchema {
  static const int currentVersion = 2;

  static const List<int> supportedVersions = [1, 2];

  static bool isVersionSupported(int version) =>
      supportedVersions.contains(version);

  /// Wraps element JSON with schema version and unknown field preservation.
  static Map<String, dynamic> wrapElement(
    Map<String, dynamic> elementJson, {
    int? version,
  }) {
    return {
      '_schemaVersion': version ?? currentVersion,
      ...elementJson,
    };
  }

  /// Extracts schema version from element JSON.
  static int extractVersion(Map<String, dynamic> json) {
    final v = json['_schemaVersion'];
    if (v is int) return v;
    return 1;
  }

  /// Validates element JSON against the schema and returns structured errors.
  static List<SchemaError> validate(Map<String, dynamic> json) {
    final errors = <SchemaError>[];
    final type = json['type'];
    if (type == null || type is! String) {
      errors.add(const SchemaError(
        field: 'type',
        code: SchemaErrorCode.missingRequired,
        message: 'Element type is required',
      ));
    }
    final id = json['id'];
    if (id == null || id is! String || (id as String).isEmpty) {
      errors.add(const SchemaError(
        field: 'id',
        code: SchemaErrorCode.missingRequired,
        message: 'Element id is required',
      ));
    }
    return errors;
  }

  /// Returns a list of field names that are not recognized by the schema.
  /// These should be preserved, not discarded.
  static Set<String> unknownFields(
    Map<String, dynamic> json,
    Set<String> knownFields,
  ) {
    return json.keys.toSet().difference(knownFields).difference(
      {'_schemaVersion', '_unknownFields'},
    );
  }

  /// Preserves unknown fields from the source JSON in the output.
  static Map<String, dynamic> preserveUnknownFields(
    Map<String, dynamic> source,
    Map<String, dynamic> output,
    Set<String> knownFields,
  ) {
    final unknown = unknownFields(source, knownFields);
    for (final key in unknown) {
      output['_unknownFields'] ??= <String, dynamic>{};
      (output['_unknownFields'] as Map<String, dynamic>)[key] = source[key];
    }
    return output;
  }
}

enum SchemaErrorCode {
  missingRequired,
  invalidType,
  unknownElementType,
  unsupportedVersion,
  corruptedData,
}

class SchemaError {
  final String field;
  final SchemaErrorCode code;
  final String message;

  const SchemaError({
    required this.field,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'SchemaError($field: $message [$code])';
}
