import 'dart:async';
import 'dart:developer' as developer;

/// Comprehensive error handling system for Smart Crop v2
class SmartCropErrorHandler {
  static final SmartCropErrorHandler _instance =
      SmartCropErrorHandler._internal();
  factory SmartCropErrorHandler() => _instance;
  SmartCropErrorHandler._internal();

  final List<CropError> _errorHistory = [];
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};

  static const int maxErrorHistorySize = 100;
  static const Duration errorCooldownPeriod = Duration(minutes: 5);

  /// Records an error with detailed context
  void recordError(CropError error) {
    _errorHistory.add(error);

    // Maintain history size limit
    if (_errorHistory.length > maxErrorHistorySize) {
      _errorHistory.removeAt(0);
    }

    // Update error counts
    final errorKey = '${error.type}_${error.analyzerName ?? 'unknown'}';
    _errorCounts[errorKey] = (_errorCounts[errorKey] ?? 0) + 1;
    _lastErrorTimes[errorKey] = DateTime.now();

    // Log error based on severity
    _logError(error);
  }

  /// Checks if an analyzer should be skipped due to recent failures
  bool shouldSkipAnalyzer(String analyzerName) {
    final errorKey = '${CropErrorType.analyzerFailure}_$analyzerName';
    final errorCount = _errorCounts[errorKey] ?? 0;
    final lastErrorTime = _lastErrorTimes[errorKey];

    // Skip if too many recent failures
    if (errorCount >= 3 && lastErrorTime != null) {
      final timeSinceLastError = DateTime.now().difference(lastErrorTime);
      if (timeSinceLastError < errorCooldownPeriod) {
        return true;
      }
    }

    return false;
  }

  /// Gets error statistics for monitoring
  Map<String, dynamic> getErrorStats() {
    final now = DateTime.now();
    final recentErrors = _errorHistory.where((error) {
      return now.difference(error.timestamp) < const Duration(hours: 1);
    }).toList();

    final errorsByType = <String, int>{};
    final errorsByAnalyzer = <String, int>{};

    for (final error in recentErrors) {
      errorsByType[error.type.toString()] =
          (errorsByType[error.type.toString()] ?? 0) + 1;

      if (error.analyzerName != null) {
        errorsByAnalyzer[error.analyzerName!] =
            (errorsByAnalyzer[error.analyzerName!] ?? 0) + 1;
      }
    }

    return {
      'total_errors': _errorHistory.length,
      'recent_errors_1h': recentErrors.length,
      'errors_by_type': errorsByType,
      'errors_by_analyzer': errorsByAnalyzer,
      'error_counts': Map.from(_errorCounts),
    };
  }

  /// Gets user-friendly error message
  String getUserFriendlyMessage(CropError error) {
    switch (error.type) {
      case CropErrorType.memoryPressure:
        return 'Processing paused due to low memory. Try closing other apps.';
      case CropErrorType.timeout:
        return 'Image processing is taking longer than expected. Using quick crop.';
      case CropErrorType.analyzerFailure:
        return 'Some advanced features are temporarily unavailable.';
      case CropErrorType.invalidInput:
        return 'Unable to process this image. Please try a different image.';
      case CropErrorType.networkError:
        return 'Network connection required for some features.';
      case CropErrorType.configurationError:
        return 'Settings have been reset to defaults.';
      case CropErrorType.resourceExhaustion:
        return 'Device resources are limited. Using simplified processing.';
      case CropErrorType.unknown:
        return 'An unexpected issue occurred. Using fallback crop.';
    }
  }

  /// Determines recovery strategy based on error type and history
  RecoveryStrategy getRecoveryStrategy(CropError error) {
    switch (error.type) {
      case CropErrorType.memoryPressure:
        return RecoveryStrategy.reduceQuality;
      case CropErrorType.timeout:
        return RecoveryStrategy.skipComplexAnalyzers;
      case CropErrorType.analyzerFailure:
        return RecoveryStrategy.skipFailedAnalyzer;
      case CropErrorType.invalidInput:
        return RecoveryStrategy.useFallbackCrop;
      case CropErrorType.networkError:
        return RecoveryStrategy.useOfflineMode;
      case CropErrorType.configurationError:
        return RecoveryStrategy.resetToDefaults;
      case CropErrorType.resourceExhaustion:
        return RecoveryStrategy.reduceQuality;
      case CropErrorType.unknown:
        return RecoveryStrategy.useFallbackCrop;
    }
  }

  /// Clears error history (for testing or reset)
  void clearErrorHistory() {
    _errorHistory.clear();
    _errorCounts.clear();
    _lastErrorTimes.clear();
  }

  /// Gets recent errors for debugging
  List<CropError> getRecentErrors({Duration? within}) {
    final cutoff = DateTime.now().subtract(within ?? const Duration(hours: 1));
    return _errorHistory
        .where((error) => error.timestamp.isAfter(cutoff))
        .toList();
  }

  void _logError(CropError error) {
    final message = 'SmartCrop Error: ${error.message}';

    switch (error.severity) {
      case ErrorSeverity.critical:
        developer.log(
          message,
          name: 'SmartCrop',
          level: 1000, // Severe
          error: error.originalError,
          stackTrace: error.stackTrace,
        );
        break;
      case ErrorSeverity.high:
        developer.log(
          message,
          name: 'SmartCrop',
          level: 900, // Warning
          error: error.originalError,
        );
        break;
      case ErrorSeverity.medium:
        developer.log(
          message,
          name: 'SmartCrop',
          level: 800, // Info
        );
        break;
      case ErrorSeverity.low:
        developer.log(
          message,
          name: 'SmartCrop',
          level: 700, // Config
        );
        break;
    }
  }
}

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
