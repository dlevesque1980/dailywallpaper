import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/subject/subject_detector.dart';

void main() {
  group('SubjectDetector', () {
    test('detectSubjects handles empty/uniform image', () {
      final size = const ui.Size(64, 64);
      final data = Uint8List(64 * 64 * 4); // All black
      for (int i = 0; i < data.length; i += 4) {
        data[i + 3] = 255;
      }
      
      final subjects = SubjectDetector.detectSubjects(size, data);
      expect(subjects.isEmpty, true);
    });

    test('detectSubjects finds high contrast subject', () {
      final size = const ui.Size(64, 64);
      final data = Uint8List(64 * 64 * 4);
      // High contrast block that overlaps cell boundaries
      // Cell size is 4x4 for 64x64 image (grid=16)
      for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) {
          final idx = (y * 64 + x) * 4;
          // Create high contrast within cells at center
          if (y >= 30 && y < 34 && x >= 30 && x < 34) {
            if ((x + y) % 2 == 0) {
              data[idx] = data[idx+1] = data[idx+2] = 255; // White
            } else {
              data[idx] = data[idx+1] = data[idx+2] = 0;   // Black
            }
          } else {
            data[idx] = data[idx+1] = data[idx+2] = 128;   // Gray
          }
          data[idx + 3] = 255;
        }
      }
      
      final subjects = SubjectDetector.detectSubjects(size, data);
      expect(subjects.isNotEmpty, true);
      expect(subjects.any((s) => s.type == SubjectType.highContrast), true);
    });

    test('detectSubjects finds distinct color subject', () {
      final size = const ui.Size(64, 64);
      final data = Uint8List(64 * 64 * 4);
      // Mostly white, with a red block that covers enough area to be "distinct"
      // Dominant color will be white.
      for (int i = 0; i < data.length; i += 4) {
        data[i] = data[i+1] = data[i+2] = 255; // White
        data[i + 3] = 255;
      }
      
      // Add red block
      for (int y = 16; y < 48; y++) {
        for (int x = 16; x < 48; x++) {
          final idx = (y * 64 + x) * 4;
          data[idx] = 255; // Red
          data[idx+1] = 0;
          data[idx+2] = 0;
        }
      }
      
      final subjects = SubjectDetector.detectSubjects(size, data);
      expect(subjects.isNotEmpty, true);
      expect(subjects.any((s) => s.type == SubjectType.colorDistinct), true);
    });
  });
}
