import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/subject/subject_scoring_logic.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/subject/subject_detector.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

void main() {
  group('SubjectScoringLogic', () {
    final subject = DetectedSubject(
      center: const ui.Offset(0.5, 0.5),
      bounds: const ui.Rect.fromLTWH(0.4, 0.4, 0.2, 0.2),
      type: SubjectType.highContrast,
      confidence: 1.0,
      importance: 1.0,
    );

    test('scoreSubjectCrop handles full inclusion', () {
      final crop = const CropCoordinates(x: 0.25, y: 0.25, width: 0.5, height: 0.5, confidence: 1.0, strategy: 'test');
      final score = SubjectScoringLogic.scoreSubjectCrop(crop, subject, 1.0, 1.0, const ui.Size(100, 100));
      expect(score, greaterThan(0.5));
    });

    test('scoreSubjectCrop handles no inclusion', () {
      final crop = const CropCoordinates(x: 0.0, y: 0.0, width: 0.1, height: 0.1, confidence: 1.0, strategy: 'test');
      final score = SubjectScoringLogic.scoreSubjectCrop(crop, subject, 1.0, 1.0, const ui.Size(100, 100));
      expect(score, lessThan(0.5));
    });
  });
}
