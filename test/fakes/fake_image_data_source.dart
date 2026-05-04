import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/datasources/bing_data_source.dart';
import 'package:dailywallpaper/data/datasources/pexels_data_source.dart';
import 'package:dailywallpaper/data/datasources/nasa_data_source.dart';

class FakeImageDataSource implements BingDataSource, PexelsDataSource, NasaDataSource {
  ImageItem? bingResult;
  ImageItem? bingThumbnailResult;
  ImageItem? pexelsResult;
  List<ImageItem>? pexelsCuratedResults;
  List<ImageItem>? pexelsSearchResults;
  ImageItem? nasaResult;
  ImageItem? nasaDateResult;
  List<ImageItem>? nasaArchiveResults;

  bool bingShouldThrow = false;
  bool pexelsShouldThrow = false;
  bool nasaShouldThrow = false;
  String throwMessage = 'Network error';

  ImageItem _defaultItem(String ident) {
    return ImageItem(
      "Source",
      "https://example.com/image.jpg",
      "Description",
      DateTime.now(),
      DateTime.now().add(const Duration(days: 1)),
      ident,
      null,
      "Copyright",
    );
  }

  @override
  Future<ImageItem> fetchFromBing(String region) async {
    if (bingShouldThrow) throw Exception(throwMessage);
    return bingResult ?? _defaultItem('bing.$region');
  }

  @override
  Future<ImageItem> fetchThumbnailFromBing(String region) async {
    if (bingShouldThrow) throw Exception(throwMessage);
    return bingThumbnailResult ?? _defaultItem('bing.thumb.$region');
  }

  @override
  Future<ImageItem> fetchFromPexels(String category) async {
    if (pexelsShouldThrow) throw Exception(throwMessage);
    return pexelsResult ?? _defaultItem('pexels.$category');
  }

  @override
  Future<List<ImageItem>> fetchPexelsCurated({int page = 1}) async {
    if (pexelsShouldThrow) throw Exception(throwMessage);
    return pexelsCuratedResults ?? [_defaultItem('pexels.curated.$page')];
  }

  @override
  Future<List<ImageItem>> searchPexelsImages({required String query, int page = 1}) async {
    if (pexelsShouldThrow) throw Exception(throwMessage);
    return pexelsSearchResults ?? [_defaultItem('pexels.search.$query.$page')];
  }

  @override
  Future<ImageItem> fetchFromNASA() async {
    if (nasaShouldThrow) throw Exception(throwMessage);
    return nasaResult ?? _defaultItem('nasa.apod');
  }

  @override
  Future<ImageItem> fetchNASAByDate(String date) async {
    if (nasaShouldThrow) throw Exception(throwMessage);
    return nasaDateResult ?? _defaultItem('nasa.$date');
  }

  @override
  Future<List<ImageItem>> fetchNASAArchive({int days = 7}) async {
    if (nasaShouldThrow) throw Exception(throwMessage);
    return nasaArchiveResults ?? [_defaultItem('nasa.archive')];
  }
}
