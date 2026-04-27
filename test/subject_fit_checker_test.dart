import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/subject_fit_checker.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

void main() {
  group('SubjectFitChecker', () {
    test('checkSubjectFit - returns original crop if coverage is ok', () {
      final crop = CropCoordinates(x: 0.1, y: 0.1, width: 0.5, height: 0.5, confidence: 0.9, strategy: 'test');
      final subject = ui.Rect.fromLTWH(0.2, 0.2, 0.2, 0.2); // Fully inside crop
      
      final result = SubjectFitChecker.checkSubjectFit(crop, subject, ui.Size(1000, 1000), ui.Size(1080, 1920));
      
      expect(result.needsScaling, false);
      expect(result.adjustedCrop.x, 0.1);
      expect(result.adjustedCrop.y, 0.1);
      expect(result.subjectCoverage, 1.0);
    });

    test('checkSubjectFit - scales crop if subject is partially outside', () {
      final crop = CropCoordinates(x: 0.2, y: 0.2, width: 0.3, height: 0.3, confidence: 0.9, strategy: 'test');
      // Subject starts inside crop but ends outside
      final subject = ui.Rect.fromLTWH(0.3, 0.3, 0.4, 0.4); 
      
      final result = SubjectFitChecker.checkSubjectFit(crop, subject, ui.Size(1000, 1000), ui.Size(1080, 1080), maxScale: 2.0);
      
      expect(result.needsScaling, true);
      expect(result.adjustedCrop.scalingApplied, true);
      expect(result.scaleFactor > 1.0, true);
      // New crop should contain more of the subject
      expect(result.subjectCoverage > 0.8, true);
      expect(result.adjustedCrop.width > 0.3, true);
    });

    test('checkSubjectFit - ignores maxScale bounds for full subject coverage', () {
      final crop = CropCoordinates(x: 0.4, y: 0.4, width: 0.1, height: 0.1, confidence: 0.9, strategy: 'test');
      final subject = ui.Rect.fromLTWH(0.0, 0.0, 1.0, 1.0); // Covers entire image
      
      final result = SubjectFitChecker.checkSubjectFit(crop, subject, ui.Size(1000, 1000), ui.Size(1080, 1080), maxScale: 1.5);
      
      expect(result.needsScaling, true);
      // We removed maxScale limiting, so the width should scale far beyond 0.15 to fit the whole 1.0 subject!
      expect(result.adjustedCrop.width > 0.15, true);
      expect(result.subjectCoverage > 0.9, true);
    });

    test('checkSubjectFit - allows overflowing image boundaries for pillarboxing', () {
      final crop = CropCoordinates(x: 0.0, y: 0.0, width: 0.5, height: 0.5, confidence: 0.9, strategy: 'test');
      final subject = ui.Rect.fromLTWH(0.0, 0.0, 1.0, 0.8);
      
      final result = SubjectFitChecker.checkSubjectFit(crop, subject, ui.Size(1000, 1000), ui.Size(1080, 1920), maxScale: 2.0);
      
      // Since it's forcing a portrait crop (1080x1920) on a landscape subject (1.0x0.8)
      // the crop bounds will need to overflow the boundaries.
      expect(result.adjustedCrop.width > 1.0 || result.adjustedCrop.height > 1.0 || result.adjustedCrop.x < 0 || result.adjustedCrop.y < 0, true);
    });
  });
}
