import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dailywallpaper/data/models/pexels/pexels_models.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:dailywallpaper/data/datasources/pexels_data_source.dart';

class PexelsService implements PexelsDataSource {
  static const String _baseUrl = 'https://api.pexels.com/v1';
  static const String _curatedEndpoint = '/curated';
  static const String _searchEndpoint = '/search';
  
  static const int _maxRequestsPerHour = 200;
  static const Duration _rateLimitWindow = Duration(hours: 1);
  static final List<DateTime> _requestTimes = [];
  
  final http.Client _client;

  PexelsService({http.Client? client}) : _client = client ?? http.Client();

  String get _apiKey {
    final key = dotenv.env['PEXELS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('PEXELS_API_KEY not found in environment variables');
    }
    return key;
  }
  
  @override
  Future<ImageItem> fetchFromPexels(String category) async {
    if (category.trim().isEmpty) {
      throw Exception('Category cannot be empty');
    }

    try {
      final pexelsPhoto = await _getRandomPhotoByCategory(category);
      if (pexelsPhoto == null) {
        throw Exception('No images found for category: $category');
      }
      return _convertPexelsPhotoToImageItem(pexelsPhoto, category);
    } catch (e) {
      throw Exception('Failed to load Pexels image: ${e.toString()}');
    }
  }

  @override
  Future<List<ImageItem>> fetchPexelsCurated({int page = 1}) async {
    try {
      final response = await _fetchCuratedPhotos(page: page, perPage: 15);
      return response.photos
          .map((photo) => _convertPexelsPhotoToImageItem(photo, 'curated'))
          .toList();
    } catch (e) {
      throw Exception('Failed to load Pexels curated images: ${e.toString()}');
    }
  }

  @override
  Future<List<ImageItem>> searchPexelsImages({required String query, int page = 1}) async {
    try {
      final response = await _searchPhotos(
        query: query,
        page: page,
        perPage: 15,
        orientation: 'portrait',
      );
      return response.photos
          .map((photo) => _convertPexelsPhotoToImageItem(photo, query))
          .toList();
    } catch (e) {
      throw Exception('Failed to search Pexels images: ${e.toString()}');
    }
  }

  ImageItem _convertPexelsPhotoToImageItem(PexelsPhoto photo, String category) {
    final photographerUrl = photo.photographerUrl;
    final photographer = photo.photographer;
    final pexelsUrl = "https://www.pexels.com";
    final referralQuery = "?utm_source=DailyWallpaper&utm_medium=referral";

    final copyright = 'Photo by <a href="$photographerUrl$referralQuery">$photographer</a> on <a href="$pexelsUrl$referralQuery">Pexels</a>';

    final startTime = DateTimeHelper.startDayDate(DateTime.now());
    final endTime = startTime.add(const Duration(days: 1));

    final imageUrl = photo.src.large2x.isNotEmpty ? photo.src.large2x : photo.src.original;

    final description = photo.alt?.isNotEmpty == true ? photo.alt! : 'Photo by ${photo.photographer}';

    return ImageItem(
      "Pexels - $category",
      imageUrl,
      description,
      startTime.toUtc(),
      endTime.toUtc(),
      'pexels.$category',
      null,
      copyright,
    );
  }

  Future<PexelsPhoto?> _getRandomPhotoByCategory(String category) async {
    try {
      final response = await _searchPhotos(
        query: category,
        page: 1,
        perPage: 80,
        orientation: 'portrait',
      );
      
      if (response.photos.isNotEmpty) {
        final randomIndex = DateTime.now().millisecondsSinceEpoch % response.photos.length;
        return response.photos[randomIndex];
      }
      return null;
    } catch (e) {
      final curatedResponse = await _fetchCuratedPhotos(perPage: 80);
      if (curatedResponse.photos.isNotEmpty) {
        final randomIndex = DateTime.now().millisecondsSinceEpoch % curatedResponse.photos.length;
        return curatedResponse.photos[randomIndex];
      }
      rethrow;
    }
  }

  Future<PexelsResponse> _fetchCuratedPhotos({int page = 1, int perPage = 15}) async {
    _checkRateLimit();
    final uri = Uri.parse('$_baseUrl$_curatedEndpoint').replace(queryParameters: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    return _doGet(uri);
  }

  Future<PexelsResponse> _searchPhotos({
    required String query,
    int page = 1,
    int perPage = 15,
    String? orientation,
  }) async {
    _checkRateLimit();
    final queryParameters = <String, String>{
      'query': query.trim(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (orientation != null) queryParameters['orientation'] = orientation;
    
    final uri = Uri.parse('$_baseUrl$_searchEndpoint').replace(queryParameters: queryParameters);
    return _doGet(uri);
  }

  Future<PexelsResponse> _doGet(Uri uri) async {
    _recordRequest();
    try {
      final response = await _client.get(uri, headers: {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 30));
      return _handleResponse(response);
    } on TimeoutException {
      throw PexelsApiException('Request timeout', 408, PexelsErrorType.networkError);
    } catch (e) {
      if (e is PexelsApiException) rethrow;
      throw PexelsApiException('Network error: $e', null, PexelsErrorType.networkError);
    }
  }

  PexelsResponse _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      return PexelsResponse.fromJson(json.decode(response.body));
    } else {
      PexelsErrorType type = PexelsErrorType.networkError;
      if (response.statusCode == 429) type = PexelsErrorType.rateLimitExceeded;
      if (response.statusCode == 401) type = PexelsErrorType.invalidApiKey;
      if (response.statusCode >= 500) type = PexelsErrorType.serverError;
      throw PexelsApiException('Pexels API error: ${response.statusCode}', response.statusCode, type);
    }
  }

  void _checkRateLimit() {
    final now = DateTime.now();
    _requestTimes.removeWhere((time) => now.difference(time) > _rateLimitWindow);
    if (_requestTimes.length >= _maxRequestsPerHour) {
      throw PexelsApiException('Rate limit exceeded', 429, PexelsErrorType.rateLimitExceeded);
    }
  }

  void _recordRequest() => _requestTimes.add(DateTime.now());
}

class PexelsApiException implements Exception {
  final String message;
  final int? statusCode;
  final PexelsErrorType type;
  PexelsApiException(this.message, this.statusCode, this.type);
  @override
  String toString() => 'PexelsApiException: $message (Status: $statusCode, Type: $type)';
}

enum PexelsErrorType { networkError, rateLimitExceeded, invalidApiKey, serverError, noContent }
