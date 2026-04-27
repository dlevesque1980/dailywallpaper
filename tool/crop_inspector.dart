import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/engine/smart_crop_engine.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/registry/analyzer_registry.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/landscape_aware_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/subject_detection_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';

/// Outil d'inspection visuelle des résultats de Smart Crop.
/// 
/// Pour lancer cet outil :
/// flutter test tool/crop_inspector.dart
Future<void> main() async {
  testWidgets('Extract Smart Cropped Images Tool', (WidgetTester tester) async {
    final settings = CropSettings.balanced.copyWith(
       enableSubjectScaling: true,
       maxScaleFactor: 2.0, // This is ignored now internally, but we set it anyway
       maxProcessingTime: const Duration(seconds: 10),
       enableMlSubjectDetection: true, // EXPLICITLY ENABLE ML
    );
    
    final engineInit = SmartCropEngine();
    await engineInit.initialize();
    
    final targetSize = ui.Size(1080, 1920); // Portrait 9:16 target
    
    // Clear cache to ensure we run analyzers
    await SmartCropper.clearCache();
    
    // Images de test dans tool/fixtures/
    const fixturesDir = 'tool/fixtures';
    const outputDir = 'tool/output';
    
    final outputDirFile = Directory(outputDir);
    if (!outputDirFile.existsSync()) {
      outputDirFile.createSync(recursive: true);
    }
    
    final files = [
      'bing_20260309.jpg',
      'CornwallDolmen_1920x1080.jpg',
      'bing-blossom.jpeg',
      'porc-epic.jpeg',
      'pinguin.jpeg',
    ];
    
    await tester.runAsync(() async {
      for (var filename in files) {
          final engine = SmartCropEngine();
          engine.dispose();
          await engine.initialize();
          
          final file = File('$fixturesDir/$filename');
          if (!file.existsSync()) {
             print('File $fixturesDir/$filename does not exist!');
             continue;
          }

          // Use Bing-optimized settings for Bing images to test the real production path
          final imageSettings = filename.contains('bing')
              ? settings.copyWith(
                  enableSubjectScaling: true,
                  minSubjectCoverage: 0.60,
                  maxScaleFactor: 3.0,
                  allowLetterbox: true,
                  enableEdgeDetection: true,
                  enableCenterWeighting: false,
                  maxProcessingTime: const Duration(seconds: 6),
                )
              : settings;
        
        print('\nProcessing: $filename (allowLetterbox=${imageSettings.allowLetterbox})');
        
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        
        final result = await engine.analyzeCrop(
           imageId: filename,
           image: image,
           targetSize: targetSize,
           settings: imageSettings,
        );
        
        if (true) {
          final best = result.bestCrop;
          final bestScore = result.bestScore;
          
          print('Best Strategy: ${best.strategy}');
          print('Best Strategy Score: ${bestScore?.score}');
          print('Best Crop: ${best.x}, ${best.y}, ${best.width} x ${best.height}');
          
          for (final score in result.allScores) {
            print('  [${score.strategy}] score=${score.score.toStringAsFixed(3)} x=${score.coordinates.x.toStringAsFixed(3)} w=${score.coordinates.width.toStringAsFixed(3)}');
          }

          final renderResult = await SmartCropper.processImage(filename, image, targetSize, imageSettings);
          final outFilename = '$outputDir/cropped_${filename.replaceAll('.jpg', '.png').replaceAll('.jpeg', '.png')}';
          
          if (renderResult.image != null) {
            final byteData = await renderResult.image!.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
               final pngBytes = byteData.buffer.asUint8List();
               await File(outFilename).writeAsBytes(pngBytes);
               print('Saved cropped image to $outFilename');
            }
          }
        }
      }
    });
  });
}
