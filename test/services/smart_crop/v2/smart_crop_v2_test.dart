import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/analyzer_metadata.dart';
import 'package:dailywallpaper/services/smart_crop/registry/analyzer_registry.dart';
import 'package:dailywallpaper/services/smart_crop/engine/smart_crop_engine.dart';
import 'package:dailywallpaper/services/smart_crop/config/configuration_manager.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

// Mock V2 analyzer for testing
class MockV2Analyzer extends BaseCropAnalyzer {
  MockV2Analyzer()
      : super(
          name: 'mock_v2_analyzer',
          priority: 200,
          weight: 0.8,
          metadata: const AnalyzerMetadata(
            description: 'Mock V2 analyzer for testing',
            version: '2.0.0',
          ),
        );

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    // Simple mock implementation
    return CropScore(
      coordinates: const CropCoordinates(
        x: 0.1,
        y: 0.1,
        width: 0.8,
        height: 0.8,
        confidence: 0.9,
        strategy: 'mock_v2_analyzer',
      ),
      score: 0.9,
      strategy: 'mock_v2_analyzer',
      metrics: {'test': true},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Crop V2 Architecture Tests', () {
    late AnalyzerRegistry registry;
    late SmartCropEngine engine;
    late ConfigurationManager configManager;

    setUp(() {
      registry = AnalyzerRegistry();
      engine = SmartCropEngine();
      configManager = ConfigurationManager();
    });

    tearDown(() {
      registry.clear();
      engine.dispose();
      configManager.dispose();
    });

    test('should register and use V2 analyzer', () async {
      // Register a V2 analyzer
      final analyzer = MockV2Analyzer();
      registry.registerAnalyzer(analyzer);

      // Verify registration
      expect(registry.getAllAnalyzers().length, equals(1));
      expect(registry.isAnalyzerEnabled('mock_v2_analyzer'), isTrue);

      // Check analyzer properties
      final registeredAnalyzer = registry.getAnalyzer('mock_v2_analyzer');
      expect(registeredAnalyzer, isNotNull);
      expect(registeredAnalyzer is CropAnalyzerV2, isTrue);

      if (registeredAnalyzer is CropAnalyzerV2) {
        expect(registeredAnalyzer.priority, equals(200));
        expect(registeredAnalyzer.weight, equals(0.8));
        expect(registeredAnalyzer.metadata.description, contains('Mock V2'));
      }
    });

    test('should handle analyzer priority sorting', () {
      // Register analyzers with different priorities
      final highPriorityAnalyzer = MockV2Analyzer();

      registry.registerAnalyzer(highPriorityAnalyzer);

      // Get enabled analyzers and verify sorting
      final enabledAnalyzers = registry.getEnabledAnalyzers();
      expect(enabledAnalyzers.length, equals(1));
      expect(enabledAnalyzers.first is CropAnalyzerV2, isTrue);
    });

    test('should initialize SmartCropEngine', () async {
      await engine.initialize();

      final stats = engine.getStats();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('engine'), isTrue);
      expect(stats.containsKey('registry'), isTrue);
      expect(stats.containsKey('performance'), isTrue);

      final engineStats = stats['engine'] as Map;
      expect(engineStats.containsKey('initialized_at'), isTrue);
    });

    test('should initialize ConfigurationManager', () async {
      // Test default profile without initialization (to avoid SharedPreferences)
      expect(configManager.currentProfile, equals(CropQualityProfile.balanced));

      // Test settings for different profiles
      final fastSettings =
          configManager.getSettingsForProfile(CropQualityProfile.fast);
      final highQualitySettings =
          configManager.getSettingsForProfile(CropQualityProfile.highQuality);

      expect(fastSettings.maxProcessingTime.inMilliseconds,
          lessThan(highQualitySettings.maxProcessingTime.inMilliseconds));
    });

    test('should handle configuration profiles', () {
      // Test settings for different profiles (doesn't require initialization)
      final fastSettings =
          configManager.getSettingsForProfile(CropQualityProfile.fast);
      final highQualitySettings =
          configManager.getSettingsForProfile(CropQualityProfile.highQuality);

      expect(fastSettings.maxProcessingTime.inMilliseconds,
          lessThan(highQualitySettings.maxProcessingTime.inMilliseconds));

      expect(fastSettings.enableRuleOfThirds, isTrue);
      expect(highQualitySettings.enableRuleOfThirds, isTrue);
      expect(fastSettings.maxCropCandidates,
          lessThanOrEqualTo(highQualitySettings.maxCropCandidates));
    });

    test('should get registry statistics', () {
      final analyzer = MockV2Analyzer();
      registry.registerAnalyzer(analyzer);

      final stats = registry.getStats();
      expect(stats['total_analyzers'], equals(1));
      expect(stats['enabled_analyzers'], equals(1));
      expect(stats['disabled_analyzers'], equals(0));
      expect(stats['load_order'], isA<List>());
      expect(stats['usage_counts'], isA<Map>());
    });

    test('should validate analyzer metadata', () {
      final analyzer = MockV2Analyzer();

      expect(analyzer.validate(), isTrue);
      expect(analyzer.metadata.description, isNotEmpty);
      expect(analyzer.metadata.version, isNotEmpty);
      expect(
          analyzer.canAnalyze(
            // Mock image with valid dimensions
            MockImage(100, 100),
            CropSettings.defaultSettings,
          ),
          isTrue);
    });
  });
}

// Mock image class for testing
class MockImage implements ui.Image {
  final int _width;
  final int _height;

  MockImage(this._width, this._height);

  @override
  int get width => _width;

  @override
  int get height => _height;

  @override
  void dispose() {}

  @override
  Future<ByteData?> toByteData(
      {ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) {
    throw UnimplementedError();
  }

  @override
  ui.ColorSpace get colorSpace => throw UnimplementedError();

  @override
  bool get debugDisposed => throw UnimplementedError();

  @override
  ui.Image clone() => throw UnimplementedError();

  @override
  bool isCloneOf(ui.Image other) => throw UnimplementedError();

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;
}
