import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';

class FakeImageCacheService implements ImageCacheService {
  final Map<String, ui.Image> sourceImages = {};
  final Map<String, ui.Image> processedImages = {};
  final Map<String, Uint8List> processedImageBytes = {};
  final Map<String, String> cropResultJsons = {};
  ui.Image? downloadedImage;

  @override
  Future<String?> downloadAndSaveSourceImage(String url, String imageIdent,
      {http.Client? client}) async {
    return 'file://fake_source_$imageIdent.jpg';
  }

  @override
  Future<ui.Image?> loadSourceImage(String imageIdent) async {
    return sourceImages[imageIdent];
  }

  @override
  Future<String?> saveProcessedImage(ui.Image image, String imageIdent) async {
    processedImages[imageIdent] = image;
    return 'file://fake_processed_$imageIdent.png';
  }

  @override
  Future<ui.Image?> loadProcessedImage(String imageIdent) async {
    return processedImages[imageIdent];
  }

  @override
  Future<Uint8List?> getProcessedImageBytes(String imageIdent) async {
    return processedImageBytes[imageIdent];
  }

  @override
  Future<void> saveCropResult(CropResult result, String imageIdent) async {
    cropResultJsons[imageIdent] = result.serialize();
  }

  @override
  Future<String?> loadCropResultJson(String imageIdent) async {
    return cropResultJsons[imageIdent];
  }

  @override
  Future<int> cleanupOldWallpapers(
      {Duration maxAge = const Duration(days: 2)}) async {
    return 0;
  }

  @override
  Future<ui.Image?> loadImageFromUrl(String url, {http.Client? client}) async {
    return downloadedImage;
  }
}
