import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dailywallpaper/services/smart_crop/utils/degradation_manager.dart';
import 'package:dailywallpaper/services/smart_crop/utils/error_handler.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/analyzer_metadata.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

// Mock analyzer for testing
class MockAnalyzer extends CropAnalyzerV2 {
  final String _name;
  final int _priority;
  final double _weight;
  final Duration _maxProcessingTime;

  MockAnalyzer({
    required String name,
    int priority = 100,
    double weight = 1.0,
    Duration maxProcessingTime = const Duration(milliseconds: 500),
  })  : _name = name,
        _priority = priority,
        _weight = weight,
        _maxProcessingTime = maxProcessingTime;

  @override
  String get name => _name;

  @override
  String get strategyName => _name;

  @override
  int get priority => _priority;

  @override
  double get weight => _weight;

  @override
  Duration get maxProcessingTime => _maxProcessingTime;

  @override
  AnalyzerMetadata get metadata => AnalyzerMetadata(
        description: 'Mock analyzer: $_name',
        version: '1.0.0',
      );

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    return CropScore(
      coordinates: CropCoordinates(
        x: 0.0,
        y: 0.0,
        width: 1.0,
        height: 1.0,
        confidence: 0.8,
        strategy: _name,
      ),
      score: 0.8,
      strategy: _name,
      metrics: {},
    );
  }
}

// Mock image for testing
class MockImage implements ui.Image {
  @override
  final int width;

  @override
  final int height;

  MockImage({this.width = 1000, this.height = 1000});

  @override
  void dispose() {}

  @override
  ui.ColorSpace get colorSpace => throw UnimplementedError();

  @override
  Future<ByteData?> toByteData(
      {ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) {
    throw UnimplementedError();
  }

  @override
  bool get debugDisposed => false;

  @override
  ui.Image clone() => this;

  @override
  bool isCloneOf(ui.Image other) => false;

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;
}

void main() {
  group('DegradationManager', () {
    late DegradationManager degradationManager;
    late ui.Image mockImage;
    late CropSettings defaultSettings;

    setUp(() {
      // Clear error history to ensure test isolation
      SmartCropErrorHandler().clearErrorHistory();
      degradationManager = DegradationManager();
      mockImage = MockImage(width: 2000, height: 1500);
      defaultSettings = CropSettings.defaultSettings;
    });

    group('Degradation Assessment', () {
      test('should return none for optimal conditions', () {
        final level = degradationManager.assessDegradationNeeds(
          image: mockImage,
          settings: defaultSettings,
          recentProcessingTime: const Duration(milliseconds: 100),
          availableMemory: 100 * 1024 * 1024, // 100MB
          recentErrors: [],
        );

        expect(level, equals(DegradationLevel.none));
      });

      test('should return high for slow processing time', () {
        final level = degradationManager.assessDegradationNeeds(
          image: mockImage,
          settings: defaultSettings,
          recentProcessingTime:
              const Duration(milliseconds: 1500), // > slowProcessingThreshold
          availableMemory: 100 * 1024 * 1024,
          recentErrors: [],
        );

        expect(level, equals(DegradationLevel.high));
      });

      test('should return medium for moderate processing time', () {
        final level = degradationManager.assessDegradationNeeds(
          image: mockImage,
          settings: defaultSettings,
          recentProcessingTime:
              const Duration(milliseconds: 700), // > normalProcessingThreshold
          availableMemory: 100 * 1024 * 1024,
          recentErrors: [],
        );

        expect(level, equals(DegradationLevel.medium));
      });

      test('should return high for critical memory shortage', () {
        final level = degradationManager.assessDegradationNeeds(
          image: mockImage,
          settings: defaultSettings,
          recentProcessingTime: const Duration(milliseconds: 100),
          availableMemory: 10 * 1024 * 1024, // 10MB < criticalMemoryThreshold
          recentErrors: [],
        );

        expect(level, equals(DegradationLevel.high));
      });

      test('should return medium for low memory', () {
        final level = degradationManager.assessDegradationNeeds(
          image: mockImage,
          settings: defaultSettings,
          recentProcessingTime: const Duration(milliseconds: 100),
          availableMemory: 30 * 1024 * 1024, // 30MB < lowMemoryThreshold
          recentErrors: [],
        );

        expect(level, equals(DegradationLevel.medium));
      });

      test('should consider large image size', () {
        final largeImage = MockImage(width: 5000, height: 4000); // > 4MP

        final level = degradationManager.assessDegradationNeeds(
          image: largeImage,
          settings: defaultSettings,
          recentProcessingTime: const Duration(milliseconds: 100),
          availableMemory: 100 * 1024 * 1024,
          recentErrors: [],
        );

        expect(level, equals(DegradationLevel.low));
      });

      test('should consider recent critical errors', () {
        final criticalErrors = [
          CropError(
            type: CropErrorType.memoryPressure,
            message: 'Critical error 1',
            severity: ErrorSeverity.critical,
          ),
          CropError(
            type: CropErrorType.analyzerFailure,
            message: 'Critical error 2',
            severity: ErrorSeverity.high,
          ),
          CropError(
            type: CropErrorType.timeout,
            message: 'Critical error 3',
            severity: ErrorSeverity.critical,
          ),
        ];

        final level = degradationManager.assessDegradationNeeds(
          image: mockImage,
          settings: defaultSettings,
          recentProcessingTime: const Duration(milliseconds: 100),
          availableMemory: 100 * 1024 * 1024,
          recentErrors: criticalErrors,
        );

        expect(level, equals(DegradationLevel.high));
      });

      test('should consider tight timeout constraints', () {
        final tightSettings = defaultSettings.copyWith(
          maxProcessingTime:
              const Duration(milliseconds: 50), // < fastProcessingThreshold
        );

        final level = degradationManager.assessDegradationNeeds(
          image: mockImage,
          settings: tightSettings,
          recentProcessingTime: const Duration(milliseconds: 100),
          availableMemory: 100 * 1024 * 1024,
          recentErrors: [],
        );

        expect(level, equals(DegradationLevel.high));
      });
    });

    group('Degraded Settings Creation', () {
      test('should return original settings for no degradation', () {
        final degradedSettings = degradationManager.createDegradedSettings(
          defaultSettings,
          DegradationLevel.none,
        );

        expect(degradedSettings, equals(defaultSettings));
      });

      test('should reduce timeout for low degradation', () {
        final degradedSettings = degradationManager.createDegradedSettings(
          defaultSettings,
          DegradationLevel.low,
        );

        expect(
          degradedSettings.maxProcessingTime.inMilliseconds,
          lessThan(defaultSettings.maxProcessingTime.inMilliseconds),
        );
        expect(degradedSettings.enableBatteryOptimization, isTrue);
        expect(degradedSettings.maxCropCandidates,
            lessThan(defaultSettings.maxCropCandidates));
      });

      test('should apply medium degradation correctly', () {
        final degradedSettings = degradationManager.createDegradedSettings(
          defaultSettings,
          DegradationLevel.medium,
        );

        expect(
          degradedSettings.maxProcessingTime.inMilliseconds,
          equals(
              (defaultSettings.maxProcessingTime.inMilliseconds * 0.6).round()),
        );
        expect(degradedSettings.enableBatteryOptimization, isTrue);
        expect(degradedSettings.enableEdgeDetection, isFalse);
        expect(degradedSettings.maxCropCandidates,
            lessThan(defaultSettings.maxCropCandidates));
      });

      test('should apply high degradation correctly', () {
        final degradedSettings = degradationManager.createDegradedSettings(
          defaultSettings,
          DegradationLevel.high,
        );

        expect(
          degradedSettings.maxProcessingTime.inMilliseconds,
          equals(
              (defaultSettings.maxProcessingTime.inMilliseconds * 0.3).round()),
        );
        expect(degradedSettings.enableBatteryOptimization, isTrue);
        expect(degradedSettings.enableEdgeDetection, isFalse);
        expect(degradedSettings.enableEntropyAnalysis, isFalse);
        expect(degradedSettings.maxCropCandidates, equals(1));
      });
    });

    group('Analyzer Filtering', () {
      late List<CropAnalyzer> testAnalyzers;

      setUp(() {
        testAnalyzers = [
          MockAnalyzer(
            name: 'fast_analyzer',
            priority: 200,
            maxProcessingTime: const Duration(milliseconds: 100),
          ),
          MockAnalyzer(
            name: 'medium_analyzer',
            priority: 150,
            maxProcessingTime: const Duration(milliseconds: 400),
          ),
          MockAnalyzer(
            name: 'slow_analyzer',
            priority: 100,
            maxProcessingTime: const Duration(milliseconds: 800),
          ),
          MockAnalyzer(
            name: 'very_slow_analyzer',
            priority: 50,
            maxProcessingTime: const Duration(milliseconds: 1200),
          ),
        ];
      });

      test('should keep all analyzers for no degradation', () {
        final filtered = degradationManager.filterAnalyzers(
          testAnalyzers,
          DegradationLevel.none,
          mockImage,
          defaultSettings,
        );

        expect(filtered.length, equals(4));
        // Should be sorted by priority (highest first)
        expect((filtered[0] as MockAnalyzer).name, equals('fast_analyzer'));
        expect((filtered[1] as MockAnalyzer).name, equals('medium_analyzer'));
      });

      test('should filter slow analyzers for low degradation', () {
        final filtered = degradationManager.filterAnalyzers(
          testAnalyzers,
          DegradationLevel.low,
          mockImage,
          defaultSettings,
        );

        // Should exclude very_slow_analyzer (> 800ms)
        expect(filtered.length, equals(3));
        expect(
            filtered
                .any((a) => (a as MockAnalyzer).name == 'very_slow_analyzer'),
            isFalse);
      });

      test('should keep only fast analyzers for medium degradation', () {
        final filtered = degradationManager.filterAnalyzers(
          testAnalyzers,
          DegradationLevel.medium,
          mockImage,
          defaultSettings,
        );

        // Should keep only analyzers <= 400ms, limited to 3
        expect(filtered.length, lessThanOrEqualTo(3));
        for (final analyzer in filtered) {
          expect((analyzer as MockAnalyzer).maxProcessingTime.inMilliseconds,
              lessThanOrEqualTo(400));
        }
      });

      test('should keep only fastest analyzer for high degradation', () {
        final filtered = degradationManager.filterAnalyzers(
          testAnalyzers,
          DegradationLevel.high,
          mockImage,
          defaultSettings,
        );

        // Should keep only analyzers <= 200ms, limited to 1
        expect(filtered.length, equals(1));
        expect((filtered[0] as MockAnalyzer).maxProcessingTime.inMilliseconds,
            lessThanOrEqualTo(200));
      });

      test('should ensure at least one analyzer is available', () {
        // Test with all slow analyzers
        final slowAnalyzers = [
          MockAnalyzer(
            name: 'slow1',
            maxProcessingTime: const Duration(milliseconds: 1000),
          ),
          MockAnalyzer(
            name: 'slow2',
            maxProcessingTime: const Duration(milliseconds: 1500),
          ),
        ];

        final filtered = degradationManager.filterAnalyzers(
          slowAnalyzers,
          DegradationLevel.high,
          mockImage,
          defaultSettings,
        );

        // Should still have at least one analyzer as fallback
        expect(filtered.length, greaterThanOrEqualTo(1));
      });
    });

    group('Fallback Chain Creation', () {
      test('should create progressive fallback chain', () {
        final fallbackChain = degradationManager.createFallbackChain(
          mockImage,
          const ui.Size(800, 600),
          defaultSettings,
        );

        expect(fallbackChain.length, equals(4));

        // Check that timeouts are progressively shorter
        for (int i = 0; i < fallbackChain.length - 1; i++) {
          expect(
            fallbackChain[i].timeout.inMilliseconds,
            greaterThan(fallbackChain[i + 1].timeout.inMilliseconds),
          );
        }

        // Check strategy names
        expect(fallbackChain[0].name, equals('reduced_quality'));
        expect(fallbackChain[1].name, equals('minimal_analyzers'));
        expect(fallbackChain[2].name, equals('single_analyzer'));
        expect(fallbackChain[3].name, equals('center_crop'));
      });

      test('should have reasonable timeout values', () {
        final fallbackChain = degradationManager.createFallbackChain(
          mockImage,
          const ui.Size(800, 600),
          defaultSettings,
        );

        // All timeouts should be positive and reasonable
        for (final strategy in fallbackChain) {
          expect(strategy.timeout.inMilliseconds, greaterThan(0));
          expect(
              strategy.timeout.inMilliseconds,
              lessThanOrEqualTo(
                  defaultSettings.maxProcessingTime.inMilliseconds));
        }

        // Center crop should be very fast
        expect(
            fallbackChain.last.timeout.inMilliseconds, lessThanOrEqualTo(100));
      });
    });

    group('Degradation Event Recording', () {
      test('should record degradation events', () {
        degradationManager.recordDegradationEvent(
          level: DegradationLevel.medium,
          reason: 'memory_pressure',
          imageId: 'test_image',
          context: {'available_memory': 1000000},
        );

        final stats = degradationManager.getDegradationStats();
        expect(stats['total_degradations'], equals(1));
        expect(stats['degradations_by_level']['DegradationLevel.medium'],
            equals(1));
      });

      test('should track multiple degradation events', () {
        degradationManager.recordDegradationEvent(
          level: DegradationLevel.low,
          reason: 'large_image',
        );
        degradationManager.recordDegradationEvent(
          level: DegradationLevel.high,
          reason: 'memory_pressure',
        );
        degradationManager.recordDegradationEvent(
          level: DegradationLevel.medium,
          reason: 'timeout_constraint',
        );

        final stats = degradationManager.getDegradationStats();
        expect(stats['total_degradations'], equals(3));
        expect(
            stats['degradations_by_level']['DegradationLevel.low'], equals(1));
        expect(
            stats['degradations_by_level']['DegradationLevel.high'], equals(1));
        expect(stats['degradations_by_level']['DegradationLevel.medium'],
            equals(1));
      });
    });

    group('Statistics', () {
      test('should provide comprehensive degradation statistics', () {
        // Record some degradation events
        degradationManager.recordDegradationEvent(
          level: DegradationLevel.medium,
          reason: 'test_reason',
        );

        final stats = degradationManager.getDegradationStats();

        expect(stats, containsPair('total_degradations', isA<int>()));
        expect(stats, containsPair('degradations_by_level', isA<Map>()));
        expect(stats, containsPair('error_stats', isA<Map>()));
      });
    });
  });

  group('FallbackStrategy', () {
    test('should create fallback strategy with correct properties', () {
      final settings = CropSettings.conservative;
      const timeout = Duration(milliseconds: 200);

      final strategy = FallbackStrategy(
        name: 'test_strategy',
        settings: settings,
        timeout: timeout,
      );

      expect(strategy.name, equals('test_strategy'));
      expect(strategy.settings, equals(settings));
      expect(strategy.timeout, equals(timeout));
    });

    test('should have meaningful toString representation', () {
      final strategy = FallbackStrategy(
        name: 'test_strategy',
        settings: CropSettings.conservative,
        timeout: const Duration(milliseconds: 300),
      );

      final string = strategy.toString();
      expect(string, contains('test_strategy'));
      expect(string, contains('300ms'));
    });
  });
}
