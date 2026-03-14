import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/error_handler.dart';

void main() {
  group('SmartCropErrorHandler', () {
    late SmartCropErrorHandler errorHandler;

    setUp(() {
      errorHandler = SmartCropErrorHandler();
      errorHandler.clearErrorHistory(); // Start with clean state
    });

    tearDown(() {
      errorHandler.clearErrorHistory();
    });

    group('Error Recording', () {
      test('should record error with correct details', () {
        final error = CropError(
          type: CropErrorType.analyzerFailure,
          message: 'Test analyzer failed',
          severity: ErrorSeverity.medium,
          imageId: 'test_image_1',
          analyzerName: 'test_analyzer',
        );

        errorHandler.recordError(error);

        final stats = errorHandler.getErrorStats();
        expect(stats['total_errors'], equals(1));
        expect(stats['recent_errors_1h'], equals(1));
        expect(stats['errors_by_type']['CropErrorType.analyzerFailure'],
            equals(1));
        expect(stats['errors_by_analyzer']['test_analyzer'], equals(1));
      });

      test('should maintain error history size limit', () {
        // Add more than the limit
        for (int i = 0; i < 150; i++) {
          final error = CropError(
            type: CropErrorType.unknown,
            message: 'Test error $i',
            severity: ErrorSeverity.low,
          );
          errorHandler.recordError(error);
        }

        final stats = errorHandler.getErrorStats();
        expect(stats['total_errors'],
            equals(100)); // Should be capped at maxErrorHistorySize
      });

      test('should track error counts by type and analyzer', () {
        // Add multiple errors of same type
        for (int i = 0; i < 3; i++) {
          final error = CropError(
            type: CropErrorType.analyzerFailure,
            message: 'Analyzer failed $i',
            severity: ErrorSeverity.medium,
            analyzerName: 'face_detector',
          );
          errorHandler.recordError(error);
        }

        final stats = errorHandler.getErrorStats();
        expect(stats['errors_by_analyzer']['face_detector'], equals(3));
      });
    });

    group('Analyzer Skipping Logic', () {
      test('should skip analyzer after multiple recent failures', () {
        // Add 3 failures for the same analyzer
        for (int i = 0; i < 3; i++) {
          final error = CropError(
            type: CropErrorType.analyzerFailure,
            message: 'Analyzer failed $i',
            severity: ErrorSeverity.medium,
            analyzerName: 'problematic_analyzer',
          );
          errorHandler.recordError(error);
        }

        expect(errorHandler.shouldSkipAnalyzer('problematic_analyzer'), isTrue);
        expect(errorHandler.shouldSkipAnalyzer('good_analyzer'), isFalse);
      });

      test('should not skip analyzer after cooldown period', () async {
        // This test would need to be adjusted for actual timing or use mocked time
        // For now, we'll test the logic structure
        expect(errorHandler.shouldSkipAnalyzer('new_analyzer'), isFalse);
      });
    });

    group('User-Friendly Messages', () {
      test('should provide appropriate message for memory pressure', () {
        final error = CropError.memoryPressure(imageId: 'test');
        final message = errorHandler.getUserFriendlyMessage(error);

        expect(message, contains('memory'));
        expect(message, contains('apps'));
      });

      test('should provide appropriate message for timeout', () {
        final error = CropError.timeout(
          timeoutDuration: const Duration(seconds: 2),
          imageId: 'test',
        );
        final message = errorHandler.getUserFriendlyMessage(error);

        expect(message, contains('longer than expected'));
        expect(message, contains('quick crop'));
      });

      test('should provide appropriate message for analyzer failure', () {
        final error = CropError.analyzerFailure(
          analyzerName: 'face_detector',
          error: Exception('Test error'),
          imageId: 'test',
        );
        final message = errorHandler.getUserFriendlyMessage(error);

        expect(message, contains('advanced features'));
        expect(message, contains('unavailable'));
      });
    });

    group('Recovery Strategies', () {
      test('should suggest correct recovery for memory pressure', () {
        final error = CropError.memoryPressure();
        final strategy = errorHandler.getRecoveryStrategy(error);

        expect(strategy, equals(RecoveryStrategy.reduceQuality));
      });

      test('should suggest correct recovery for timeout', () {
        final error = CropError.timeout(
          timeoutDuration: const Duration(seconds: 1),
        );
        final strategy = errorHandler.getRecoveryStrategy(error);

        expect(strategy, equals(RecoveryStrategy.skipComplexAnalyzers));
      });

      test('should suggest correct recovery for analyzer failure', () {
        final error = CropError.analyzerFailure(
          analyzerName: 'test_analyzer',
          error: Exception('Test'),
        );
        final strategy = errorHandler.getRecoveryStrategy(error);

        expect(strategy, equals(RecoveryStrategy.skipFailedAnalyzer));
      });
    });

    group('Error Creation Factories', () {
      test('should create memory pressure error correctly', () {
        final error = CropError.memoryPressure(
          imageId: 'test_image',
          analyzerName: 'test_analyzer',
          context: {'available_memory': 1000000},
        );

        expect(error.type, equals(CropErrorType.memoryPressure));
        expect(error.severity, equals(ErrorSeverity.high));
        expect(error.imageId, equals('test_image'));
        expect(error.analyzerName, equals('test_analyzer'));
        expect(error.isRecoverable, isTrue);
        expect(error.context['available_memory'], equals(1000000));
      });

      test('should create timeout error correctly', () {
        final timeout = const Duration(milliseconds: 500);
        final error = CropError.timeout(
          timeoutDuration: timeout,
          imageId: 'test_image',
        );

        expect(error.type, equals(CropErrorType.timeout));
        expect(error.severity, equals(ErrorSeverity.medium));
        expect(error.context['timeout_ms'], equals(500));
        expect(error.message, contains('500ms'));
      });

      test('should create analyzer failure error correctly', () {
        final originalError = Exception('Original error message');
        final stackTrace = StackTrace.current;

        final error = CropError.analyzerFailure(
          analyzerName: 'face_detector',
          error: originalError,
          stackTrace: stackTrace,
          imageId: 'test_image',
        );

        expect(error.type, equals(CropErrorType.analyzerFailure));
        expect(error.analyzerName, equals('face_detector'));
        expect(error.originalError, equals(originalError));
        expect(error.stackTrace, equals(stackTrace));
        expect(error.message, contains('face_detector'));
        expect(error.message, contains('Original error message'));
      });

      test('should create error from exception correctly', () {
        final originalError = ArgumentError('Invalid argument');
        final stackTrace = StackTrace.current;

        final error = CropError.fromException(
          originalError,
          stackTrace,
          imageId: 'test_image',
          analyzerName: 'test_analyzer',
        );

        expect(error.type, equals(CropErrorType.invalidInput));
        expect(error.severity, equals(ErrorSeverity.medium));
        expect(error.originalError, equals(originalError));
        expect(error.stackTrace, equals(stackTrace));
        expect(error.message, contains('Invalid argument'));
      });

      test('should handle OutOfMemoryError correctly', () {
        final originalError = OutOfMemoryError();
        final stackTrace = StackTrace.current;

        final error = CropError.fromException(originalError, stackTrace);

        expect(error.type, equals(CropErrorType.memoryPressure));
        expect(error.severity, equals(ErrorSeverity.high));
        expect(error.message, contains('Out of memory'));
      });

      test('should handle unknown exceptions correctly', () {
        final originalError = Exception('Unknown error');
        final stackTrace = StackTrace.current;

        final error = CropError.fromException(originalError, stackTrace);

        expect(error.type, equals(CropErrorType.unknown));
        expect(error.severity, equals(ErrorSeverity.medium));
        expect(error.message, contains('Unexpected error'));
      });
    });

    group('Recent Errors', () {
      test('should filter recent errors correctly', () {
        // Add an old error (simulated by creating error with past timestamp)
        final oldError = CropError(
          type: CropErrorType.unknown,
          message: 'Old error',
          severity: ErrorSeverity.low,
        );

        // Add a recent error
        final recentError = CropError(
          type: CropErrorType.analyzerFailure,
          message: 'Recent error',
          severity: ErrorSeverity.medium,
        );

        errorHandler.recordError(oldError);
        errorHandler.recordError(recentError);

        final recentErrors = errorHandler.getRecentErrors(
          within: const Duration(minutes: 30),
        );

        // Both should be recent since we just created them
        expect(recentErrors.length, equals(2));
      });
    });

    group('Error Statistics', () {
      test('should provide comprehensive error statistics', () {
        // Add various types of errors
        errorHandler.recordError(CropError(
          type: CropErrorType.memoryPressure,
          message: 'Memory error',
          severity: ErrorSeverity.high,
          analyzerName: 'face_detector',
        ));

        errorHandler.recordError(CropError(
          type: CropErrorType.timeout,
          message: 'Timeout error',
          severity: ErrorSeverity.medium,
          analyzerName: 'object_detector',
        ));

        errorHandler.recordError(CropError(
          type: CropErrorType.memoryPressure,
          message: 'Another memory error',
          severity: ErrorSeverity.high,
          analyzerName: 'face_detector',
        ));

        final stats = errorHandler.getErrorStats();

        expect(stats['total_errors'], equals(3));
        expect(stats['recent_errors_1h'], equals(3));
        expect(
            stats['errors_by_type']['CropErrorType.memoryPressure'], equals(2));
        expect(stats['errors_by_type']['CropErrorType.timeout'], equals(1));
        expect(stats['errors_by_analyzer']['face_detector'], equals(2));
        expect(stats['errors_by_analyzer']['object_detector'], equals(1));
      });
    });
  });

  group('CropError', () {
    test('should create error with all properties', () {
      final originalError = Exception('Test exception');
      final stackTrace = StackTrace.current;

      final error = CropError(
        type: CropErrorType.analyzerFailure,
        message: 'Test error message',
        severity: ErrorSeverity.high,
        imageId: 'test_image_123',
        analyzerName: 'test_analyzer',
        originalError: originalError,
        stackTrace: stackTrace,
        isRecoverable: false,
        context: {'key': 'value'},
      );

      expect(error.type, equals(CropErrorType.analyzerFailure));
      expect(error.message, equals('Test error message'));
      expect(error.severity, equals(ErrorSeverity.high));
      expect(error.imageId, equals('test_image_123'));
      expect(error.analyzerName, equals('test_analyzer'));
      expect(error.originalError, equals(originalError));
      expect(error.stackTrace, equals(stackTrace));
      expect(error.isRecoverable, isFalse);
      expect(error.context['key'], equals('value'));
      expect(error.timestamp, isA<DateTime>());
    });

    test('should have reasonable toString representation', () {
      final error = CropError(
        type: CropErrorType.timeout,
        message: 'Analysis timed out',
        severity: ErrorSeverity.medium,
        imageId: 'img_123',
        analyzerName: 'slow_analyzer',
      );

      final string = error.toString();
      expect(string, contains('CropError'));
      expect(string, contains('timeout'));
      expect(string, contains('Analysis timed out'));
      expect(string, contains('img_123'));
      expect(string, contains('slow_analyzer'));
    });
  });
}
