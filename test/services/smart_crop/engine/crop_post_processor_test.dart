import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/engine/crop_post_processor.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import '../../../fakes/fake_image.dart';

void main() {
  group('CropPostProcessor', () {
    late CropPostProcessor processor;

    setUp(() {
      processor = CropPostProcessor();
    });

    test('postProcess applies letterbox for landscape image', () {
      final image = FakeImage(width: 2000, height: 1000); // 2:1
      final targetSize = const ui.Size(1080, 2400); // Portrait target
      final bestCrop = const CropCoordinates(x: 0.45, y: 0.45, width: 0.1, height: 0.1, confidence: 1.0, strategy: 'test');
      final settings = CropSettings.defaultSettings.copyWith(allowLetterbox: true);

      final result = processor.postProcess(
        bestCrop: bestCrop,
        allScores: [CropScore(strategy: 'test', score: 1.0, coordinates: bestCrop, metrics: const {})],
        image: image,
        targetSize: targetSize,
        settings: settings,
      );

      expect(result.strategy, 'test_letterbox');
      expect(result.width, 0.5); // targetLetterboxWidth
    });

    test('postProcess does not apply letterbox if disabled', () {
      final image = FakeImage(width: 2000, height: 1000);
      final targetSize = const ui.Size(1080, 2400);
      final bestCrop = const CropCoordinates(x: 0.45, y: 0.45, width: 0.1, height: 0.1, confidence: 1.0, strategy: 'test');
      final settings = CropSettings.defaultSettings.copyWith(allowLetterbox: false);

      final result = processor.postProcess(
        bestCrop: bestCrop,
        allScores: [CropScore(strategy: 'test', score: 1.0, coordinates: bestCrop, metrics: const {})],
        image: image,
        targetSize: targetSize,
        settings: settings,
      );

      expect(result.strategy, 'test');
    });
  });
}
