import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/smart_crop/analyzers/ml/ml_isolate_runner.dart';

void main() {
  group('MlIsolateRunner', () {
    test('MlIsolatePayload should be transmissible (only primitive types)', () {
      final payload = MlIsolatePayload(
        pngBytes: Uint8List.fromList([1, 2, 3]),
        originalWidth: 100,
        originalHeight: 100,
        tempDirPath: '/tmp',
      );

      expect(payload.pngBytes.length, 3);
      expect(payload.originalWidth, 100);
      expect(payload.originalHeight, 100);
      expect(payload.tempDirPath, '/tmp');
    });

    test('MlIsolateResult structure is valid', () {
      final result = MlIsolateResult(
        subjectX: 0.5,
        subjectY: 0.5,
        subjectWidth: 0.2,
        subjectHeight: 0.2,
        confidence: 0.9,
        error: null,
      );

      expect(result.confidence, 0.9);
      expect(result.error, isNull);
    });

    test('runMlSegmentationInIsolate returns error if ML Kit fails (invalid bytes)', () async {
      final payload = MlIsolatePayload(
        pngBytes: Uint8List(0), // Invalid bytes
        originalWidth: 100,
        originalHeight: 100,
        tempDirPath: '/tmp',
      );

      // It should gracefully return an error instead of throwing an unhandled exception in the isolate
      final result = await runMlSegmentationInIsolate(payload);
      expect(result.error, isNotNull);
    });
  });
}
