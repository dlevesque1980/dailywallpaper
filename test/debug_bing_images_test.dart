import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dailywallpaper/services/smart_crop/engine/smart_crop_engine.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/landscape_aware_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/subject_detection_crop_analyzer.dart';

class MyHttpOverrides extends HttpOverrides {}

Future<void> main() async {
  testWidgets('Debug Smart Cropper on March 3 & March 9 Bing Images', (WidgetTester tester) async {
    HttpOverrides.global = MyHttpOverrides();
    // Default setting the app uses now
    final settings = CropSettings.balanced.copyWith(
       enableSubjectScaling: true,
       maxScaleFactor: 2.0, // balanced defaults to 2.0
    );
    
    final engine = SmartCropEngine();
    await engine.initialize();
    engine.registerAnalyzer(LandscapeAwareCropAnalyzer());
    engine.registerAnalyzer(SubjectDetectionCropAnalyzer());
    
    final targetSize = ui.Size(1080, 1920);
    
    // Bing api for 'idx=0 n=15'
    final url = Uri.parse('https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=15&mkt=en-US');
    final response = await http.get(url);
    final data = json.decode(response.body);
    final images = data['images'] as List;
    
    // March 14 is idx=0. March 9 is idx=5. March 3 is idx=11.
    final targetIndices = [5, 11];
    
    for (var idx in targetIndices) {
        if (idx >= images.length) continue;
        final img = images[idx];
        final title = img['title'];
        final date = img['startdate'];
        final urlBase = img['urlbase'];
        final fullUrl = 'https://www.bing.com\${urlBase}_1920x1080.jpg';
        
        print('\n=======================================');
        print('Date: \$date | Title: \$title');
        print('=======================================');
        
        final imgRes = await http.get(Uri.parse(fullUrl));
        final bytes = imgRes.bodyBytes;
        
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        
        print('Original Size: \${image.width} x \${image.height}');
        
        final result = await engine.analyzeCrop(
           imageId: 'test_\$idx',
           image: image,
           targetSize: targetSize,
           settings: settings,
        );
        
        print('Strategy: \${result.bestCrop.strategy}');
        print('Confidence: \${result.bestCrop.confidence.toStringAsFixed(3)}');
        print('Score: \${result.bestScore?.score.toStringAsFixed(3) ?? "N/A"}');
        print('Final Crop (x,y,w,h): \${result.bestCrop.x.toStringAsFixed(3)}, \${result.bestCrop.y.toStringAsFixed(3)}, \${result.bestCrop.width.toStringAsFixed(3)} x \${result.bestCrop.height.toStringAsFixed(3)}');
        print('Scaling Applied: \${result.bestCrop.scalingApplied}');
        
        // Dump the metrics to see what the analyzers found
        final metrics = result.bestScore?.metrics ?? {};
        print('METRICS:');
        for (var key in metrics.keys) {
           print('  \$key: \${metrics[key]?.toStringAsFixed(3)}');
        }
    }
  });
}
