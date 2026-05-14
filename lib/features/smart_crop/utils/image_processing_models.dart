import 'dart:async';
import 'dart:collection';
import '../models/crop_coordinates.dart';
import '../interfaces/crop_analyzer.dart';

class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

class AnalyzerGroups {
  final List<CropAnalyzer> highPriority;
  final List<CropAnalyzer> mediumPriority;
  final List<CropAnalyzer> lowPriority;

  const AnalyzerGroups({
    required this.highPriority,
    required this.mediumPriority,
    required this.lowPriority,
  });
}

class CropAnalysisResult {
  final String analyzerName;
  final CropCoordinates coordinates;
  final Duration processingTime;
  final double confidence;
  final String? error;

  const CropAnalysisResult({
    required this.analyzerName,
    required this.coordinates,
    required this.processingTime,
    required this.confidence,
    this.error,
  });

  bool get isSuccessful => error == null;

  @override
  String toString() {
    return 'CropAnalysisResult($analyzerName: confidence=${confidence.toStringAsFixed(2)}, '
        'time=${processingTime.inMilliseconds}ms, success=$isSuccessful)';
  }
}

class CacheStats {
  final int cachedImages;
  final int processingImages;

  const CacheStats({
    required this.cachedImages,
    required this.processingImages,
  });

  @override
  String toString() {
    return 'CacheStats(cached: $cachedImages, processing: $processingImages)';
  }
}

enum CropQuality {
  fast,
  balanced,
  highQuality,
}

enum AnalyzerPriority {
  high,
  medium,
  low,
}

extension CropAnalyzerPriority on CropAnalyzer {
  AnalyzerPriority get priority {
    switch (strategyName.toLowerCase()) {
      case 'face_detection':
      case 'object_detection':
        return AnalyzerPriority.high;
      case 'composition':
      case 'rule_of_thirds':
        return AnalyzerPriority.medium;
      default:
        return AnalyzerPriority.low;
    }
  }
}
