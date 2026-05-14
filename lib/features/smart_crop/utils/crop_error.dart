import 'dart:async';

/// Represents different types of crop analysis errors
enum CropErrorType {
  memoryPressure,
  timeout,
  analyzerFailure,
  invalidInput,
  networkError,
  configurationError,
  resourceExhaustion,
  unknown,
}

/// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Recovery strategies for different error types
enum RecoveryStrategy {
  retry,
  reduceQuality,
  skipComplexAnalyzers,
  skipFailedAnalyzer,
  useFallbackCrop,
  useOfflineMode,
  resetToDefaults,
}

/// Detailed error information for crop analysis failures
class CropError {
  final CropErrorType type;
  final String message;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final String? imageId;
  final String? analyzerName;
  final Object? originalError;
  final StackTrace? stackTrace;
  final bool isRecoverable;
  final Map<String, dynamic> context;

  CropError({
    required this.type,
    required this.message,
    required this.severity,
    this.imageId,
    this.analyzerName,
    this.originalError,
    this.stackTrace,
    this.isRecoverable = true,
    this.context = const {},
  }) : timestamp = DateTime.now();

  /// Creates an error from an exception
  factory CropError.fromException(
    Object exception,
    StackTrace stackTrace, {
    String? imageId,
    String? analyzerName,
    Map<String, dynamic> context = const {},
  }) {
    CropErrorType type;
    ErrorSeverity severity;
    String message;
    bool isRecoverable = true;

    if (exception is OutOfMemoryError) {
      type = CropErrorType.memoryPressure;
      severity = ErrorSeverity.high;
      message = 'Out of memory during crop analysis';
    } else if (exception is TimeoutException) {
      type = CropErrorType.timeout;
      severity = ErrorSeverity.medium;
      message = 'Crop analysis timed out';
    } else if (exception is ArgumentError) {
      type = CropErrorType.invalidInput;
      severity = ErrorSeverity.medium;
      message = 'Invalid input parameters: ${exception.message}';
    } else if (exception is StateError) {
      type = CropErrorType.configurationError;
      severity = ErrorSeverity.high;
      message = 'Configuration error: ${exception.message}';
    } else {
      type = CropErrorType.unknown;
      severity = ErrorSeverity.medium;
      message = 'Unexpected error: ${exception.toString()}';
    }

    return CropError(
      type: type,
      message: message,
      severity: severity,
      imageId: imageId,
      analyzerName: analyzerName,
      originalError: exception,
      stackTrace: stackTrace,
      isRecoverable: isRecoverable,
      context: context,
    );
  }

  /// Creates a memory pressure error
  factory CropError.memoryPressure({
    String? imageId,
    String? analyzerName,
    Map<String, dynamic> context = const {},
  }) {
    return CropError(
      type: CropErrorType.memoryPressure,
      message: 'Memory pressure detected during crop analysis',
      severity: ErrorSeverity.high,
      imageId: imageId,
      analyzerName: analyzerName,
      isRecoverable: true,
      context: context,
    );
  }

  /// Creates a timeout error
  factory CropError.timeout({
    required Duration timeoutDuration,
    String? imageId,
    String? analyzerName,
    Map<String, dynamic> context = const {},
  }) {
    return CropError(
      type: CropErrorType.timeout,
      message: 'Analysis timed out after ${timeoutDuration.inMilliseconds}ms',
      severity: ErrorSeverity.medium,
      imageId: imageId,
      analyzerName: analyzerName,
      isRecoverable: true,
      context: {
        'timeout_ms': timeoutDuration.inMilliseconds,
        ...context,
      },
    );
  }

  /// Creates an analyzer failure error
  factory CropError.analyzerFailure({
    required String analyzerName,
    required Object error,
    StackTrace? stackTrace,
    String? imageId,
    Map<String, dynamic> context = const {},
  }) {
    return CropError(
      type: CropErrorType.analyzerFailure,
      message: 'Analyzer "$analyzerName" failed: ${error.toString()}',
      severity: ErrorSeverity.medium,
      imageId: imageId,
      analyzerName: analyzerName,
      originalError: error,
      stackTrace: stackTrace,
      isRecoverable: true,
      context: context,
    );
  }

  @override
  String toString() {
    return 'CropError(type: $type, message: $message, severity: $severity, '
        'imageId: $imageId, analyzerName: $analyzerName, '
        'isRecoverable: $isRecoverable)';
  }
}
