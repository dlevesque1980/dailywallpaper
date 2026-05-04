import 'package:dailywallpaper/data/models/image_item.dart';

abstract class PexelsDataSource {
  Future<ImageItem> fetchFromPexels(String category);
  Future<List<ImageItem>> fetchPexelsCurated({int page = 1});
  Future<List<ImageItem>> searchPexelsImages({required String query, int page = 1});
}
