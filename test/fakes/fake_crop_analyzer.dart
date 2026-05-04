import 'dart:ui' as ui;
import 'package:dailywallpaper/services/smart_crop/interfaces/crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/analysis_context.dart';

class FakeCropAnalyzer extends CropAnalyzerV2 {
  final String _name;
  final double _weight;
  final bool _enabled;

  FakeCropAnalyzer(this._name, {double weight = 1.0, bool enabled = true}) 
    : _weight = weight, _enabled = enabled;

  @override
  String get strategyName => _name;

  @override
  double get weight => _weight;

  @override
  bool get isEnabledByDefault => _enabled;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    return CropScore.empty(_name);
  }

  @override
  Future<CropScore> analyzeWithContext(ui.Image image, ui.Size targetSize, AnalysisContext context) async {
    return analyze(image, targetSize);
  }

  @override
  bool validate() => true;
}
