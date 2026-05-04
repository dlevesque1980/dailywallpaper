import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/engine/smart_crop_engine.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/battery_optimizer.dart';
import 'package:dailywallpaper/services/smart_crop/utils/device_capability_detector.dart';

class CropAnalyzerService {
  final SmartCropEngine _engine = SmartCropEngine();
  
  Future<CropResult> analyzeCrop({
    required String imageUrl,
    required ui.Image image,
    required ui.Size targetSize,
    required CropSettings settings,
    required DeviceCapability deviceCapability,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (!_engine.isInitialized) {
        await _engine.initialize();
      }

      // Apply battery optimizations
      final optimizedSettings =
          await BatteryOptimizer.optimizeSettingsForBattery(settings);

      // Check if processing should be deferred
      if (await BatteryOptimizer.shouldDeferProcessing()) {
        final delay = await BatteryOptimizer.getRecommendedProcessingDelay();
        await Future.delayed(delay);
      }

      final result = await _engine.analyzeCrop(
        image: image,
        targetSize: targetSize,
        settings: optimizedSettings,
        imageId: imageUrl,
        metadata: {
          'source': 'crop_analyzer_service',
          'version': '2.0',
        },
      );

      stopwatch.stop();
      return result.copyWith(processingTime: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      // Fallback center crop on error
      return _createFallbackResult(image, targetSize, stopwatch.elapsed, e.toString());
    }
  }

  CropResult _createFallbackResult(
    ui.Image image, 
    ui.Size targetSize, 
    Duration elapsed, 
    String error
  ) {
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = image.width / image.height;

    double cropWidth, cropHeight;
    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }

    final bestCrop = CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth.clamp(0.1, 1.0),
      height: cropHeight.clamp(0.1, 1.0),
      confidence: 0.5,
      strategy: 'fallback_center',
    );

    return CropResult(
      bestCrop: bestCrop,
      allScores: [],
      processingTime: elapsed,
      fromCache: false,
      analyzerMetadata: {'error': error},
      performanceMetrics: PerformanceMetrics(
        totalTime: elapsed,
        analyzerTimes: {},
        memoryUsage: 0,
        analyzersExecuted: 0,
        analyzersSkipped: 0,
        cacheHitRate: 0.0,
      ),
      scoringBreakdown: {},
    );
  }

  Future<void> close() async {
    // No explicit close needed for engine currently
  }
}
