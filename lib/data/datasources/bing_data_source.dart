import 'package:dailywallpaper/data/models/image_item.dart';

abstract class BingDataSource {
  Future<ImageItem> fetchFromBing(String region);
  Future<ImageItem> fetchThumbnailFromBing(String region);
}
