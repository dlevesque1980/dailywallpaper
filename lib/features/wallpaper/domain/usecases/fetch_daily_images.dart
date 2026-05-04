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
      await _dbHelper.insertImage(image);
    }
    return image;
  }

  Future<List<ImageItem>> _fetchPexelsParallel({bool forceRefresh = false}) async {
    var categories = await _prefHelper.getStringListWithDefault(
        sp_PexelsCategories, defaultPexelsCategories.take(3).toList());

    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();

    var futures = categories
        .map((category) => _fetchSinglePexels(category, dateStr, forceRefresh: forceRefresh))
        .toList();

    var results = await Future.wait(futures);
    return results.whereType<ImageItem>().toList();
  }

  Future<ImageItem?> _fetchSinglePexels(String category, String dateStr, {bool forceRefresh = false}) async {
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
        await _dbHelper.insertImage(pexelsImage);
      }
      return pexelsImage;
    } catch (e) {
      debugPrint('Error loading Pexels image for category $category: $e');
      return null;
    }
  }

  Future<ImageItem?> _nasaHandler({bool forceRefresh = false}) async {
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();
    var imageIdent = 'nasa.apod.$dateStr';

    try {
      ImageItem? nasaImage;

      if (forceRefresh) {
        await _dbHelper.deleteImageByIdent(imageIdent);
      } else {
        nasaImage = await _dbHelper.getCurrentImage(imageIdent);
      }

      if (nasaImage == null) {
        nasaImage = await _imageRepository.fetchFromNASA();
        nasaImage.imageIdent = imageIdent;
        await _dbHelper.insertImage(nasaImage);
      }

      return nasaImage;
    } catch (e) {
      debugPrint('Error loading NASA APOD: $e');
      return null;
    }
  }
}
