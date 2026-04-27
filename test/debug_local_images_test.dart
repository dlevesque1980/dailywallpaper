import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/engine/smart_crop_engine.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/registry/analyzer_registry.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/landscape_aware_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/subject_detection_crop_analyzer.dart';

import 'package:dailywallpaper/services/smart_crop/analyzers/face_detection_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/object_detection_crop_analyzer.dart';

Future<void> main() async {
  testWidgets('Debug Smart Cropper on Local Images', (WidgetTester tester) async {
    final settings = CropSettings.balanced.copyWith(
       enableSubjectScaling: true,
       maxScaleFactor: 2.0, 
       maxProcessingTime: const Duration(seconds: 10),
    );
    
    final engineInit = SmartCropEngine();
    await engineInit.initialize();
    
    // Clear registry just in case
    AnalyzerRegistry().clear();
    
    engineInit.registerAnalyzer(LandscapeAwareCropAnalyzer());
    engineInit.registerAnalyzer(SubjectDetectionCropAnalyzer());
    
    final targetSize = ui.Size(1080, 1920);
    
    final files = [
      'bing_20260309.jpg',         
      'CornwallDolmen_1920x1080.jpg',         
    ];
    
    await tester.runAsync(() async {
      for (var filename in files) {
          final engine = SmartCropEngine();
          // We don't initialize because that registers default analyzers, and we already registered them.
          // Alternatively, we just initialize, it won't crash if we don't call registerAnalyzer again.
          await engine.initialize();
          
          final file = File(filename);
          if (!file.existsSync()) {
             print('File \$filename does not exist!');
             continue;
          }
        
        print('\n=======================================');
        print('Testing: $filename');
        print('=======================================');
        
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        
        print('Original Size: ${image.width} x ${image.height}');
        
        final result = await engine.analyzeCrop(
           imageId: filename,
           image: image,
           targetSize: targetSize,
           settings: settings,
        );
        
        // Manual debug of analyzers
        print('--- Direct Analyzer Tests ---');
        final faceAnalyzer = FaceDetectionCropAnalyzer();
        final objAnalyzer = ObjectDetectionCropAnalyzer();
        try {
          final faceScore = await faceAnalyzer.analyze(image, targetSize);
          print('Direct Face Score: ${faceScore.score}');
          print('Direct Face Metrics: ${faceScore.metrics}');
        } catch (e) {
          print('Face Analyzer Error: $e');
        }
        try {
          final objScore = await objAnalyzer.analyze(image, targetSize);
          print('Direct Obj Score: ${objScore.score}');
          print('Direct Obj Metrics: ${objScore.metrics}');
        } catch (e) {
          print('Obj Analyzer Error: $e');
        }
        
        print('Strategy: ${result.bestCrop.strategy}');
        print('Confidence: ${result.bestCrop.confidence.toStringAsFixed(3)}');
        print('Score: ${result.bestScore?.score.toStringAsFixed(3) ?? "N/A"}');
        print('Final Crop (x,y,w,h): ${result.bestCrop.x.toStringAsFixed(3)}, ${result.bestCrop.y.toStringAsFixed(3)}, ${result.bestCrop.width.toStringAsFixed(3)} x ${result.bestCrop.height.toStringAsFixed(3)}');
        print('Scaling Applied: ${result.bestCrop.scalingApplied}');
        
        print('ALL STRATEGIES:');
        for (final score in result.allScores) {
          print(' - ${score.strategy}: ${score.score.toStringAsFixed(3)}');
        }
        final metrics = result.bestScore?.metrics ?? {};
        print('METRICS:');
        for (var key in metrics.keys) {
           print('  $key: ${metrics[key]?.toStringAsFixed(3)}');
        }
      }
    });
  });
}
