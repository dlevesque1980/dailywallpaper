import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/datasources/bing_data_source.dart';
import 'package:dailywallpaper/data/datasources/bing_service.dart';
import 'package:dailywallpaper/data/datasources/nasa_data_source.dart';
import 'package:dailywallpaper/data/datasources/nasa_service.dart';
import 'package:dailywallpaper/data/datasources/pexels_data_source.dart';
import 'package:dailywallpaper/data/datasources/pexels_service.dart';

class ImageRepository {
  final BingDataSource _bingDataSource;
  final PexelsDataSource _pexelsDataSource;
  final NasaDataSource _nasaDataSource;

  ImageRepository({
    BingDataSource? bingDataSource,
    PexelsDataSource? pexelsDataSource,
    NasaDataSource? nasaDataSource,
  })  : _bingDataSource = bingDataSource ?? BingService(),
        _pexelsDataSource = pexelsDataSource ?? PexelsService(),
        _nasaDataSource = nasaDataSource ?? NasaService();

  // Bing
  Future<ImageItem> fetchFromBing(String region) => 
      _bingDataSource.fetchFromBing(region);

  Future<ImageItem> fetchThumbnailFromBing(String region) => 
      _bingDataSource.fetchThumbnailFromBing(region);

  // Pexels
  Future<ImageItem> fetchFromPexels(String category) => 
      _pexelsDataSource.fetchFromPexels(category);

  Future<List<ImageItem>> fetchPexelsCurated({int page = 1}) => 
      _pexelsDataSource.fetchPexelsCurated(page: page);

  Future<List<ImageItem>> searchPexelsImages({
    required String query,
    int page = 1,
  }) => _pexelsDataSource.searchPexelsImages(query: query, page: page);

  // NASA
  Future<ImageItem> fetchFromNASA() => 
      _nasaDataSource.fetchFromNASA();

  Future<ImageItem> fetchNASAByDate(String date) => 
      _nasaDataSource.fetchNASAByDate(date);

  Future<List<ImageItem>> fetchNASAArchive({int days = 7}) => 
      _nasaDataSource.fetchNASAArchive(days: days);

  /// Validate image URL accessibility
  Future<bool> validateImageUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
