import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:dailywallpaper/core/database/image_storage.dart';

class FetchHistoryUseCase {
  final ImageStorage _dbHelper;

  FetchHistoryUseCase({ImageStorage? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<List<DateTime>> getAvailableDates() async {
    return await _dbHelper.getAvailableDates();
  }

  Future<List<ImageItem>> getImagesForDate(DateTime date) async {
    return await _dbHelper.getImagesForDate(date);
  }
}
