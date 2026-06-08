enum AppFailureCode {
  cancelled,
  invalidInput,
  notFound,
  permissionDenied,
  requiresRestart,
  unsupportedPlatform,
  unsupported,
  notConfigured,
  unavailable,
  fileSystem,
  ioFailure,
  platform,
  nativeFailure,
  serialization,
  unknown,
}

class AppFailure {
  final AppFailureCode code;
  final String message;
  final String recoverySuggestion;
  final String nativeCode;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppFailure({
    required this.code,
    required this.message,
    this.recoverySuggestion = '',
    this.nativeCode = '',
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() {
    return recoverySuggestion.isEmpty
        ? message
        : '$message $recoverySuggestion';
  }
}

class AppResult<T> {
  final T? value;
  final AppFailure? failure;

  const AppResult._({this.value, this.failure});

  const AppResult.success([T? value]) : this._(value: value);

  const AppResult.failure(AppFailure failure) : this._(failure: failure);

  bool get isSuccess => failure == null;

  bool get isFailure => failure != null;

  AppFailure get requireFailure {
    final currentFailure = failure;
    if (currentFailure == null) {
      throw StateError('Result has no failure.');
    }
    return currentFailure;
  }

  T get requireValue {
    final currentValue = value;
    if (currentValue == null) {
      throw StateError(failure?.message ?? 'Result has no value.');
    }
    return currentValue;
  }
}
