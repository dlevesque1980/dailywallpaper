import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/datasources/bing_data_source.dart';
import 'package:dailywallpaper/data/datasources/pexels_data_source.dart';
import 'package:dailywallpaper/data/datasources/nasa_data_source.dart';

class FakeBingDataSource implements BingDataSource {
  ImageItem? item;
  @override
  Future<ImageItem> fetchFromBing(String region) async => item!;
  @override
  Future<ImageItem> fetchThumbnailFromBing(String region) async => item!;
}

class FakePexelsDataSource implements PexelsDataSource {
  ImageItem? item;
  List<ImageItem>? list;
  @override
  Future<ImageItem> fetchFromPexels(String category) async => item!;
  @override
  Future<List<ImageItem>> fetchPexelsCurated({int page = 1}) async => list!;
  @override
  Future<List<ImageItem>> searchPexelsImages({required String query, int page = 1}) async => list!;
}

class FakeNasaDataSource implements NasaDataSource {
  ImageItem? item;
  List<ImageItem>? list;
  @override
  Future<ImageItem> fetchFromNASA() async => item!;
  @override
  Future<ImageItem> fetchNASAByDate(String date) async => item!;
  @override
  Future<List<ImageItem>> fetchNASAArchive({int days = 7}) async => list!;
}
