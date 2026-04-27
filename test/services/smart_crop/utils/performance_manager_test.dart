import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/performance_manager.dart';

void main() {
  group('PerformanceManager', () {
    late PerformanceManager performanceManager;

    setUp(() {
      performanceManager = PerformanceManager();
    });

    tearDown(() async {
      await performanceManager.optimizePerformance(); // This clears metrics
      await performanceManager.dispose();
    });

    test('should initialize successfully', () async {
      // This test verifies that the performance manager can be initialized
      // without throwing exceptions
      expect(() => performanceManager.initialize(), returnsNormally);
    });

    test('should record performance metrics', () {
      final metric = PerformanceMetric.success(
        analyzerName: 'test_analyzer',
        processingTime: const Duration(milliseconds: 100),
        confidence: 0.8,
      );

      performanceManager.recordMetric(metric);

      final stats = performanceManager.getPerformanceStats();
      expect(stats.totalOperations, equals(1));
      expect(stats.averageProcessingTime,
          equals(const Duration(milliseconds: 100)));
      expect(stats.successRate, equals(1.0));
    });

    test('should calculate success rate correctly', () {
      // Record successful metrics
      for (int i = 0; i < 8; i++) {
        performanceManager.recordMetric(PerformanceMetric.success(
          analyzerName: 'test_analyzer',
          processingTime: const Duration(milliseconds: 100),
          confidence: 0.8,
        ));
      }

      // Record failed metrics
      for (int i = 0; i < 2; i++) {
        performanceManager.recordMetric(PerformanceMetric.failure(
          analyzerName: 'test_analyzer',
          processingTime: const Duration(milliseconds: 50),
          error: 'Test error',
        ));
      }

      final stats = performanceManager.getPerformanceStats();
      expect(stats.totalOperations, equals(10));
      expect(stats.successRate, equals(0.8));
    });

    test('should provide analyzer-specific statistics', () {
      // Record metrics for different analyzers
      performanceManager.recordMetric(PerformanceMetric.success(
        analyzerName: 'face_detection',
        processingTime: const Duration(milliseconds: 200),
        confidence: 0.9,
      ));

      performanceManager.recordMetric(PerformanceMetric.success(
        analyzerName: 'edge_detection',
        processingTime: const Duration(milliseconds: 50),
        confidence: 0.7,
      ));

      final analyzerStats = performanceManager.getAnalyzerStats();
      expect(analyzerStats.containsKey('face_detection'), isTrue);
      expect(analyzerStats.containsKey('edge_detection'), isTrue);

      expect(analyzerStats['face_detection']!.averageProcessingTime,
          equals(const Duration(milliseconds: 200)));
      expect(analyzerStats['edge_detection']!.averageProcessingTime,
          equals(const Duration(milliseconds: 50)));
    });

    test('should handle empty metrics gracefully', () {
      final stats = performanceManager.getPerformanceStats();
      expect(stats.totalOperations, equals(0));
      expect(stats.successRate, equals(0.0));
      expect(stats.averageProcessingTime, equals(Duration.zero));
    });

    test('should create performance metrics correctly', () {
      final successMetric = PerformanceMetric.success(
        analyzerName: 'test_analyzer',
        processingTime: const Duration(milliseconds: 100),
        confidence: 0.8,
      );

      expect(successMetric.isSuccessful, isTrue);
      expect(successMetric.analyzerName, equals('test_analyzer'));
      expect(successMetric.processingTime,
          equals(const Duration(milliseconds: 100)));
      expect(successMetric.confidence, equals(0.8));
      expect(successMetric.error, isNull);

      final failureMetric = PerformanceMetric.failure(
        analyzerName: 'test_analyzer',
        processingTime: const Duration(milliseconds: 50),
        error: 'Test error',
      );

      expect(failureMetric.isSuccessful, isFalse);
      expect(failureMetric.error, equals('Test error'));
      expect(failureMetric.confidence, isNull);
    });

    test('should limit metrics collection size', () {
      // Record more than 1000 metrics
      for (int i = 0; i < 1100; i++) {
        performanceManager.recordMetric(PerformanceMetric.success(
          analyzerName: 'test_analyzer',
          processingTime: Duration(milliseconds: i % 100),
          confidence: 0.8,
        ));
      }

      final stats = performanceManager.getPerformanceStats();
      // Should keep only the most recent 1000 metrics
      expect(stats.totalOperations, equals(1000));
    });

    test('should optimize performance successfully', () async {
      // Record some metrics first
      performanceManager.recordMetric(PerformanceMetric.success(
        analyzerName: 'test_analyzer',
        processingTime: const Duration(milliseconds: 100),
        confidence: 0.8,
      ));

      // Optimize performance
      await performanceManager.optimizePerformance();

      // Metrics should be cleared
      final stats = performanceManager.getPerformanceStats();
      expect(stats.totalOperations, equals(0));
    });
  });

  group('PerformanceMetric', () {
    test('should create success metric correctly', () {
      final metric = PerformanceMetric.success(
        analyzerName: 'test_analyzer',
        processingTime: const Duration(milliseconds: 100),
        confidence: 0.8,
      );

      expect(metric.isSuccessful, isTrue);
      expect(metric.analyzerName, equals('test_analyzer'));
      expect(metric.processingTime, equals(const Duration(milliseconds: 100)));
      expect(metric.confidence, equals(0.8));
      expect(metric.error, isNull);
    });

    test('should create failure metric correctly', () {
      final metric = PerformanceMetric.failure(
        analyzerName: 'test_analyzer',
        processingTime: const Duration(milliseconds: 50),
        error: 'Test error',
      );

      expect(metric.isSuccessful, isFalse);
      expect(metric.analyzerName, equals('test_analyzer'));
      expect(metric.processingTime, equals(const Duration(milliseconds: 50)));
      expect(metric.error, equals('Test error'));
      expect(metric.confidence, isNull);
    });

    test('should have valid timestamp', () {
      final beforeCreation = DateTime.now();
      final metric = PerformanceMetric.success(
        analyzerName: 'test_analyzer',
        processingTime: const Duration(milliseconds: 100),
      );
      final afterCreation = DateTime.now();

      expect(
          metric.timestamp.isAfter(beforeCreation) ||
              metric.timestamp.isAtSameMomentAs(beforeCreation),
          isTrue);
      expect(
          metric.timestamp.isBefore(afterCreation) ||
              metric.timestamp.isAtSameMomentAs(afterCreation),
          isTrue);
    });
  });

  group('PerformanceStats', () {
    test('should calculate percentages correctly', () {
      const stats = PerformanceStats(
        averageProcessingTime: Duration(milliseconds: 100),
        successRate: 0.85,
        memoryUsageMB: 50.5,
        cacheHitRate: 0.75,
        totalOperations: 100,
      );

      expect(stats.successRatePercentage, equals(85.0));
      expect(stats.cacheHitRatePercentage, equals(75.0));
    });

    test('should have meaningful string representation', () {
      const stats = PerformanceStats(
        averageProcessingTime: Duration(milliseconds: 150),
        successRate: 0.9,
        memoryUsageMB: 75.2,
        cacheHitRate: 0.8,
        totalOperations: 50,
      );

      final stringRep = stats.toString();
      expect(stringRep, contains('150ms'));
      expect(stringRep, contains('90.0%'));
      expect(stringRep, contains('75.2MB'));
      expect(stringRep, contains('80.0%'));
    });
  });

  group('AnalyzerPerformanceStats', () {
    test('should create stats correctly', () {
      const stats = AnalyzerPerformanceStats(
        analyzerName: 'face_detection',
        averageProcessingTime: Duration(milliseconds: 200),
        successRate: 0.95,
        totalOperations: 25,
      );

      expect(stats.analyzerName, equals('face_detection'));
      expect(stats.averageProcessingTime,
          equals(const Duration(milliseconds: 200)));
      expect(stats.successRate, equals(0.95));
      expect(stats.totalOperations, equals(25));
    });

    test('should have meaningful string representation', () {
      const stats = AnalyzerPerformanceStats(
        analyzerName: 'edge_detection',
        averageProcessingTime: Duration(milliseconds: 75),
        successRate: 0.88,
        totalOperations: 40,
      );

      final stringRep = stats.toString();
      expect(stringRep, contains('edge_detection'));
      expect(stringRep, contains('75ms'));
      expect(stringRep, contains('88.0%'));
      expect(stringRep, contains('40 ops'));
    });
  });
}
