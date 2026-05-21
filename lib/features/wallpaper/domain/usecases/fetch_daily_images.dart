import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/database/image_storage.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:flutter/foundation.dart';

class FetchDailyImagesUseCase {
  final ImageStorage _dbHelper;
  final ImageRepository _imageRepository;
  final PreferencesReader _prefHelper;

  FetchDailyImagesUseCase({
    ImageStorage? dbHelper,
    ImageRepository? imageRepository,
    PreferencesReader? prefHelper,
  })  : _dbHelper = dbHelper ?? DatabaseHelper(),
        _imageRepository = imageRepository ?? ImageRepository(),
        _prefHelper = prefHelper ?? PrefHelperAdapter();

  Future<List<ImageItem>> call({bool forceRefresh = false}) async {
    final list = <ImageItem>[];

    // Clean up old images periodically (keep last 30 days)
    _dbHelper.cleanupOldImages(daysToKeep: 30);
    // Clean up physical files and db references older than 2 days
    unawaited(_dbHelper.cleanupOldFilesAndReferences(daysToKeepFiles: 2));

    // Launch all API requests concurrently
    var bingFuture = _bingHandler(forceRefresh: forceRefresh);
    var pexelsFutures = _fetchPexelsParallel(forceRefresh: forceRefresh);
    var nasaFuture = _nasaHandler(forceRefresh: forceRefresh);

    var results = await Future.wait([
      bingFuture,
      pexelsFutures,
      nasaFuture,
    ]);

    // Add Bing result
    if (results[0] != null) {
      list.add(results[0] as ImageItem);
    }

    // Add Pexels results
    if (results[1] != null) {
      list.addAll(results[1] as List<ImageItem>);
    }

    // Add NASA result
    var nasaResult = results[2] as ImageItem?;
    if (nasaResult != null) {
      list.add(nasaResult);
    }

    await _resolvePhysicalPaths(list);
    return list;
  }

  Future<ImageItem?> _bingHandler({bool forceRefresh = false}) async {
    ImageItem? image;
    var region = await _prefHelper.getStringWithDefault(sp_BingRegion, 'en-US');
    var imageIdent = "bing.$region";

    if (forceRefresh) {
      await _dbHelper.deleteImageByIdent(imageIdent);
    } else {
      image = await _dbHelper.getCurrentImage(imageIdent);
    }

    if (image == null) {
      image = await _imageRepository.fetchFromBing(region);
      image.displayOrder = 0;
      await _dbHelper.insertImage(image);
    }
    return image;
  }

  Future<List<ImageItem>> _fetchPexelsParallel(
      {bool forceRefresh = false}) async {
    var categories = await _prefHelper.getStringListWithDefault(
        sp_PexelsCategories, defaultPexelsCategories.take(3).toList());

    var dateStr = DateTimeHelper.formatDateKey(DateTime.now());

    var futures = <Future<ImageItem?>>[];
    for (int i = 0; i < categories.length; i++) {
      futures.add(_fetchSinglePexels(categories[i], dateStr, i + 1,
          forceRefresh: forceRefresh));
    }

    var results = await Future.wait(futures);
    return results.whereType<ImageItem>().toList();
  }

  Future<ImageItem?> _fetchSinglePexels(
      String category, String dateStr, int order,
      {bool forceRefresh = false}) async {
    try {
      var imageIdent = 'pexels.$category.$dateStr';
      ImageItem? pexelsImage;

      if (forceRefresh) {
        await _dbHelper.deleteImageByIdent(imageIdent);
      } else {
        pexelsImage = await _dbHelper.getCurrentImage(imageIdent);
      }

      if (pexelsImage == null) {
        pexelsImage = await _imageRepository.fetchFromPexels(category);
        pexelsImage.imageIdent = imageIdent;
        pexelsImage.displayOrder = order;
        await _dbHelper.insertImage(pexelsImage);
      }
      return pexelsImage;
    } catch (e) {
      debugPrint('Error loading Pexels image for category $category: $e');
      return null;
    }
  }

  Future<ImageItem?> _nasaHandler({bool forceRefresh = false}) async {
    var dateStr = DateTimeHelper.formatDateKey(DateTime.now());
    var imageIdent = 'nasa.$dateStr';

    try {
      ImageItem? nasaImage;

      if (forceRefresh) {
        await _dbHelper.deleteImageByIdent(imageIdent);
      } else {
        nasaImage = await _dbHelper.getCurrentImage(imageIdent);
      }

      if (nasaImage == null) {
        nasaImage = await _imageRepository.fetchFromNASA();
        // Use the ident from service if possible, but ensure consistency
        nasaImage.imageIdent = imageIdent;
        nasaImage.displayOrder = 999;
        await _dbHelper.insertImage(nasaImage);
      }

      return nasaImage;
    } catch (e) {
      debugPrint('Error loading NASA APOD: $e');
      return null;
    }
  }

  /// Retourne les dernières images mises en cache (Zero-Latency Carousel)
  Future<List<ImageItem>> getCachedImages() async {
    try {
      final list = await _dbHelper.getHistoricalImages(limit: 10);
      if (list.isEmpty) return [];

      // Filtrer pour garder le lot d'images le plus récent (par exemple de la dernière date de début)
      final latestStartTime = list.first.startTime;
      final dailyBatch = list
          .where((img) =>
              img.startTime.difference(latestStartTime).inHours.abs() < 24)
          .toList();

      // Trier le lot par DisplayOrder
      dailyBatch.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      await _resolvePhysicalPaths(dailyBatch);
      return dailyBatch;
    } catch (e) {
      debugPrint('Error getting cached images: $e');
      return [];
    }
  }

  Future<void> _resolvePhysicalPaths(List<ImageItem> list) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (final img in list) {
        if (img.localSourcePath == null) {
          final filePath = '${appDir.path}/wallpapers/${img.imageIdent}_source.jpg';
          if (await File(filePath).exists()) {
            img.localSourcePath = filePath;
            unawaited(_dbHelper.updateImagePaths(img.imageIdent, localSourcePath: filePath));
          }
        }
        if (img.localProcessedPath == null) {
          final filePath = '${appDir.path}/wallpapers/${img.imageIdent}_processed.png';
          if (await File(filePath).exists()) {
            img.localProcessedPath = filePath;
            unawaited(_dbHelper.updateImagePaths(img.imageIdent, localProcessedPath: filePath));
          }
        }
      }
    } catch (e) {
      debugPrint('Error resolving physical paths: $e');
    }
  }
}
