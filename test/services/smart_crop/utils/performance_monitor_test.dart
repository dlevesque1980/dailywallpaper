import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/performance_monitor.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;
    
    setUp(() {
      monitor = PerformanceMonitor();
      monitor.clear();
    });
    
    test('should record successful operations', () {
      monitor.recordSuccess('test_operation', const Duration(milliseconds: 100));
      
      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 1);
      expect(stats.successfulOperations, 1);
      expect(stats.failedOperations, 0);
      expect(stats.successRate, 1.0);
    });
    
    test('should record failed operations', () {
      monitor.recordFailure(
        'test_operation', 
        const Duration(milliseconds: 100), 
        'Test error',
      );
      
      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 1);
      expect(stats.successfulOperations, 0);
      expect(stats.failedOperations, 1);
      expect(stats.successRate, 0.0);
    });
    
    test('should record metrics with metadata', () {
      monitor.recordSuccess(
        'test_operation',
        const Duration(milliseconds: 100),
        metadata: {'test_key': 'test_value'},
      );
      
      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 1);
    });
    
    test('should calculate correct statistics', () {
      // Record multiple operations
      monitor.recordSuccess('op1', const Duration(milliseconds: 100));
      monitor.recordSuccess('op1', const Duration(milliseconds: 200));
      monitor.recordFailure('op1', const Duration(milliseconds: 150), 'Error');
      
      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 3);
      expect(stats.successfulOperations, 2);
      expect(stats.failedOperations, 1);
      expect(stats.successRate, closeTo(0.667, 0.01));
      expect(stats.averageDuration.inMilliseconds, 150);
    });
    
    test('should track operation-specific statistics', () {
      monitor.recordSuccess('op1', const Duration(milliseconds: 100));
      monitor.recordSuccess('op2', const Duration(milliseconds: 200));
      monitor.recordFailure('op1', const Duration(milliseconds: 150), 'Error');
      
      final op1Stats = monitor.getOperationStats('op1');
      expect(op1Stats, isNotNull);
      expect(op1Stats!.totalCount, 2);
      expect(op1Stats.successCount, 1);
      expect(op1Stats.failureCount, 1);
      expect(op1Stats.successRate, 0.5);
      
      final op2Stats = monitor.getOperationStats('op2');
      expect(op2Stats, isNotNull);
      expect(op2Stats!.totalCount, 1);
      expect(op2Stats.successCount, 1);
      expect(op2Stats.failureCount, 0);
      expect(op2Stats.successRate, 1.0);
    });
    
    test('should provide performance trends', () {
      // Record some operations
      for (int i = 0; i < 10; i++) {
        monitor.recordSuccess('test_op', Duration(milliseconds: 100 + i * 10));
      }
      
      final trends = monitor.getPerformanceTrends();
      expect(trends.recentHourMetrics, 10);
      expect(trends.dailyMetrics, 10);
      expect(trends.recentHourSuccessRate, 1.0);
      expect(trends.dailySuccessRate, 1.0);
    });
    
    test('should track memory usage statistics', () {
      monitor.recordSuccess(
        'test_op',
        const Duration(milliseconds: 100),
        metadata: {'memory_usage_mb': 50.0},
      );
      monitor.recordSuccess(
        'test_op',
        const Duration(milliseconds: 100),
        metadata: {'memory_usage_mb': 75.0},
      );
      
      final memoryStats = monitor.getMemoryUsageStats();
      expect(memoryStats.samplesCount, 2);
      expect(memoryStats.averageMemoryMB, 62.5);
      expect(memoryStats.minMemoryMB, 50.0);
      expect(memoryStats.maxMemoryMB, 75.0);
    });
    
    test('should track cache performance', () {
      monitor.recordSuccess(
        'test_op',
        const Duration(milliseconds: 50),
        metadata: {'from_cache': true},
      );
      monitor.recordSuccess(
        'test_op',
        const Duration(milliseconds: 150),
        metadata: {'from_cache': false},
      );
      
      final cacheStats = monitor.getCachePerformanceStats();
      expect(cacheStats.cacheHits, 1);
      expect(cacheStats.cacheMisses, 1);
      expect(cacheStats.cacheHitRate, 0.5);
    });
    
    test('should export analytics data', () {
      monitor.recordSuccess('test_op', const Duration(milliseconds: 100));
      
      final analyticsData = monitor.exportAnalyticsData();
      expect(analyticsData, isA<Map<String, dynamic>>());
      expect(analyticsData.containsKey('overall_stats'), isTrue);
      expect(analyticsData.containsKey('trends'), isTrue);
      expect(analyticsData.containsKey('memory_stats'), isTrue);
      expect(analyticsData.containsKey('cache_stats'), isTrue);
      expect(analyticsData.containsKey('operation_stats'), isTrue);
      expect(analyticsData.containsKey('export_timestamp'), isTrue);
    });
    
    test('should handle empty statistics', () {
      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 0);
      expect(stats.successRate, 1.0);
      expect(stats.averageDuration, Duration.zero);
      
      final memoryStats = monitor.getMemoryUsageStats();
      expect(memoryStats.samplesCount, 0);
      expect(memoryStats.averageMemoryMB, 0.0);
    });
    
    test('should clear all data', () {
      monitor.recordSuccess('test_op', const Duration(milliseconds: 100));
      expect(monitor.getOverallStats().totalOperations, 1);
      
      monitor.clear();
      expect(monitor.getOverallStats().totalOperations, 0);
    });
    
    test('should maintain size limits', () {
      // Record more than the limit
      for (int i = 0; i < 1200; i++) {
        monitor.recordSuccess('test_op', Duration(milliseconds: i));
      }
      
      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, lessThanOrEqualTo(1000)); // Should be capped
    });
    
    test('should convert stats to map correctly', () {
      monitor.recordSuccess('test_op', const Duration(milliseconds: 100));
      
      final stats = monitor.getOverallStats();
      final statsMap = stats.toMap();
      
      expect(statsMap, isA<Map<String, dynamic>>());
      expect(statsMap['total_operations'], stats.totalOperations);
      expect(statsMap['success_rate'], stats.successRate);
      expect(statsMap['average_duration_ms'], stats.averageDuration.inMilliseconds);
    });
  });
}