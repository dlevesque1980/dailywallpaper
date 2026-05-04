import 'package:dailywallpaper/core/database/image_storage.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

class FakeImageStorage implements ImageStorage {
  final Map<String, ImageItem> _store = {};
  int insertCallCount = 0;
  int deleteCallCount = 0;

  void seed(ImageItem item) {
    _store[item.imageIdent] = item;
  }

  @override
  Future<bool> insertImage(ImageItem image) async {
    insertCallCount++;
    _store[image.imageIdent] = image;
    return true;
  }

  @override
  Future<ImageItem?> getCurrentImage(String imageIdent) async {
    return _store[imageIdent];
  }

  @override
  Future<List<ImageItem>> getHistoricalImages({int limit = 30}) async {
    final list = _store.values.toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list.take(limit).toList();
  }

  @override
  Future<void> cleanupOldImages({int daysToKeep = 30}) async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: daysToKeep));
    _store.removeWhere((key, value) => value.startTime.isBefore(cutoff));
  }

  @override
  Future<List<ImageItem>> getImagesForDate(DateTime date) async {
    return _store.values.where((item) {
      return item.startTime.year == date.year &&
             item.startTime.month == date.month &&
             item.startTime.day == date.day;
    }).toList();
  }

  @override
  Future<void> deleteImageByIdent(String imageIdent) async {
    deleteCallCount++;
    _store.remove(imageIdent);
  }

  @override
  Future<List<DateTime>> getAvailableDates() async {
    final dates = _store.values.map((item) {
      return DateTime(item.startTime.year, item.startTime.month, item.startTime.day);
    }).toSet().toList();
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }
}
