import 'package:dailywallpaper/data/models/image_item.dart';

abstract class NasaDataSource {
  Future<ImageItem> fetchFromNASA();
  Future<ImageItem> fetchNASAByDate(String date);
  Future<List<ImageItem>> fetchNASAArchive({int days = 7});
}
