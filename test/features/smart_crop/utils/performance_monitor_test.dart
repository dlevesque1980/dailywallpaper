import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/smart_crop/utils/performance_monitor.dart';
import 'package:dailywallpaper/features/smart_crop/utils/performance_monitor_models.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;

    setUp(() {
      monitor = PerformanceMonitor();
      monitor.clear();
    });

    test('recordSuccess adds a successful metric', () {
      monitor.recordSuccess('test_op', const Duration(milliseconds: 100));

      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 1);
      expect(stats.successfulOperations, 1);
      expect(stats.failedOperations, 0);
      expect(stats.successRate, 1.0);
    });

    test('recordFailure adds a failed metric', () {
      monitor.recordFailure(
          'test_op', const Duration(milliseconds: 100), 'error');

      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 1);
      expect(stats.successfulOperations, 0);
      expect(stats.failedOperations, 1);
      expect(stats.successRate, 0.0);
    });

    test('enforces max history limit of 1000', () {
      for (int i = 0; i < 1050; i++) {
        monitor.recordSuccess('test_op', const Duration(milliseconds: 10));
      }

      final stats = monitor.getOverallStats();
      expect(stats.totalOperations, 1000); // Should cap at 1000
    });

    test('getOperationStats returns correct specific stats', () {
      monitor.recordSuccess('op_A', const Duration(milliseconds: 10));
      monitor.recordSuccess('op_A', const Duration(milliseconds: 20));
      monitor.recordFailure('op_B', const Duration(milliseconds: 50), 'err');

      final statsA = monitor.getOperationStats('op_A');
      expect(statsA?.totalCount, 2);
      expect(statsA?.successCount, 2);

      final statsB = monitor.getOperationStats('op_B');
      expect(statsB?.totalCount, 1);
      expect(statsB?.failureCount, 1);
    });
  });
}
