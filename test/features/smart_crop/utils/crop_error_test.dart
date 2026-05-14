import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/smart_crop/utils/crop_error.dart';

void main() {
  group('CropError', () {
    test('fromException handles TimeoutException', () {
      final exception = TimeoutException('Test timeout');
      final stackTrace = StackTrace.current;
      
      final error = CropError.fromException(exception, stackTrace);
      
      expect(error.type, CropErrorType.timeout);
      expect(error.severity, ErrorSeverity.medium);
      expect(error.message, 'Crop analysis timed out');
      expect(error.isRecoverable, isTrue);
    });

    test('fromException handles OutOfMemoryError', () {
      final exception = OutOfMemoryError();
      final stackTrace = StackTrace.current;
      
      final error = CropError.fromException(exception, stackTrace);
      
      expect(error.type, CropErrorType.memoryPressure);
      expect(error.severity, ErrorSeverity.high);
      expect(error.message, 'Out of memory during crop analysis');
      expect(error.isRecoverable, isTrue);
    });

    test('timeout factory creates correct error', () {
      final error = CropError.timeout(timeoutDuration: const Duration(milliseconds: 500));
      
      expect(error.type, CropErrorType.timeout);
      expect(error.message, 'Analysis timed out after 500ms');
      expect(error.context['timeout_ms'], 500);
    });
  });
}
