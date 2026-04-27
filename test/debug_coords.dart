import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/engine/smart_crop_engine.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/entropy_based_crop_analyzer.dart';

Future<void> main() async {
  testWidgets('Debug Coords', (WidgetTester tester) async {
    final settings = CropSettings.balanced.copyWith(
       enableSubjectScaling: true,
       maxScaleFactor: 2.0,
       maxProcessingTime: const Duration(seconds: 10),
    );
    
    final targetSize = ui.Size(1080, 1920); // Portrait 9:16 target
    final files = ['CornwallDolmen_1920x1080.jpg'];
    
    await tester.runAsync(() async {
      for (var filename in files) {
          final engine = SmartCropEngine();
          engine.dispose();
          await engine.initialize();
          engine.registerAnalyzer(EntropyBasedCropAnalyzer());
          
          final file = File(filename);
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final image = frame.image;
          
          final result = await engine.analyzeCrop(
             imageId: filename,
             image: image,
             targetSize: targetSize,
             settings: settings,
          );
          
          print('--- $filename ---');
          for (final score in result.allScores) {
             print('${score.strategy}: ${score.score} x=${score.coordinates.x}');
          }
      }
    });
  });
}
