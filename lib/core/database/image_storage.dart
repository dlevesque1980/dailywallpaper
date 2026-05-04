import 'package:dailywallpaper/data/models/image_item.dart';

abstract class ImageStorage {
  Future<bool> insertImage(ImageItem image);
  Future<ImageItem?> getCurrentImage(String imageIdent);
  Future<List<ImageItem>> getHistoricalImages({int limit = 30});
  Future<void> cleanupOldImages({int daysToKeep = 30});
  Future<List<ImageItem>> getImagesForDate(DateTime date);
  Future<void> deleteImageByIdent(String imageIdent);
  Future<List<DateTime>> getAvailableDates();
}
