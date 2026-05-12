import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:dailywallpaper/services/smart_crop/models/crop_result.dart';

abstract class ImageCacheService {
  Future<String?> downloadAndSaveSourceImage(String url, String imageIdent, {http.Client? client});
  Future<ui.Image?> loadSourceImage(String imageIdent);
  Future<String?> saveProcessedImage(ui.Image image, String imageIdent);
  Future<ui.Image?> loadProcessedImage(String imageIdent);
  Future<Uint8List?> getProcessedImageBytes(String imageIdent);
  Future<void> saveCropResult(CropResult result, String imageIdent);
  Future<String?> loadCropResultJson(String imageIdent);
  Future<int> cleanupOldWallpapers({Duration maxAge});
  Future<ui.Image?> loadImageFromUrl(String url, {http.Client? client});
}

class ImageCacheServiceImpl implements ImageCacheService {
  @override
  Future<String?> downloadAndSaveSourceImage(String url, String imageIdent, {http.Client? client}) async {
    try {
      final response = await (client ?? http.Client()).get(Uri.parse(url));
      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        final wallpaperDir = Directory('${appDir.path}/wallpapers');
        if (!await wallpaperDir.exists()) {
          await wallpaperDir.create(recursive: true);
        }
        final filePath = '${wallpaperDir.path}/${imageIdent}_source.jpg';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ui.Image?> loadSourceImage(String imageIdent) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/wallpapers/${imageIdent}_source.jpg';
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> saveProcessedImage(ui.Image image, String imageIdent) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) {
        await wallpaperDir.create(recursive: true);
      }
      final filePath = '${wallpaperDir.path}/${imageIdent}_processed.png';
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return filePath;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<ui.Image?> loadProcessedImage(String imageIdent) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/wallpapers/${imageIdent}_processed.png';
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Uint8List?> getProcessedImageBytes(String imageIdent) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/wallpapers/${imageIdent}_processed.png';
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> saveCropResult(CropResult result, String imageIdent) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) {
        await wallpaperDir.create(recursive: true);
      }
      final filePath = '${wallpaperDir.path}/${imageIdent}_crop.json';
      final file = File(filePath);
      await file.writeAsString(result.serialize());
    } catch (e) {
      // Ignore
    }
  }

  @override
  Future<String?> loadCropResultJson(String imageIdent) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/wallpapers/${imageIdent}_crop.json';
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> cleanupOldWallpapers({Duration maxAge = const Duration(days: 2)}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final wallpaperDir = Directory('${appDir.path}/wallpapers');
      if (!await wallpaperDir.exists()) return 0;
      
      final cutoffTime = DateTime.now().subtract(maxAge);
      int deletedCount = 0;
      await for (final entity in wallpaperDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      return deletedCount;
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<ui.Image?> loadImageFromUrl(String url, {http.Client? client}) async {
    try {
      final response = await (client ?? http.Client()).get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
