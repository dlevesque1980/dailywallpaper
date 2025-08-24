import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dailywallpaper/models/pexels/pexels_models.dart';

class PexelsService {
  static const String _baseUrl = 'https://api.pexels.com/v1';
  static const String _curatedEndpoint = '/curated';
  static const String _searchEndpoint = '/search';
  
  // Rate limiting constants
  static const int _maxRequestsPerHour = 200;
  static const Duration _rateLimitWindow = Duration(hours: 1);
  
  // Request tracking for rate limiting
  static final List<DateTime> _requestTimes = [];
  
  /// Get API key from environment variables
  static String get _apiKey {
    final key = dotenv.env['PEXELS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('PEXELS_API_KEY not found in environment variables');
    }
    return key;
  }
  
  /// Check if we're within rate limits
  static bool _isWithinRateLimit() {
    final now = DateTime.now();
    // Remove requests older than 1 hour
    _requestTimes.removeWhere((time) => now.difference(time) > _rateLimitWindow);
    
    return _requestTimes.length < _maxRequestsPerHour;
  }
  
  /// Record a new request for rate limiting
  static void _recordRequest() {
    _requestTimes.add(DateTime.now());
  }
  
  /// Create HTTP headers for Pexels API
  static Map<String, String> _getHeaders() {
    return {
      'Authorization': _apiKey,
      'Content-Type': 'application/json',
    };
  }
  
  /// Handle HTTP response and errors
  static PexelsResponse _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return PexelsResponse.fromJson(jsonData);
    } else if (response.statusCode == 429) {
      throw PexelsApiException(
        'Rate limit exceeded. Please try again later.',
        response.statusCode,
        PexelsErrorType.rateLimitExceeded,
      );
    } else if (response.statusCode == 401) {
      throw PexelsApiException(
        'Invalid API key. Please check your PEXELS_API_KEY.',
        response.statusCode,
        PexelsErrorType.invalidApiKey,
      );
    } else if (response.statusCode >= 500) {
      throw PexelsApiException(
        'Pexels server error. Please try again later.',
        response.statusCode,
        PexelsErrorType.serverError,
      );
    } else {
      throw PexelsApiException(
        'Failed to fetch images: ${response.reasonPhrase}',
        response.statusCode,
        PexelsErrorType.networkError,
      );
    }
  }
  
  /// Fetch curated photos from Pexels
  /// 
  /// [page] - Page number (default: 1)
  /// [perPage] - Number of photos per page (default: 15, max: 80)
  static Future<PexelsResponse> fetchCuratedPhotos({
    int page = 1,
    int perPage = 15,
  }) async {
    if (!_isWithinRateLimit()) {
      throw PexelsApiException(
        'Rate limit exceeded. Please try again later.',
        429,
        PexelsErrorType.rateLimitExceeded,
      );
    }
    
    // Validate parameters
    if (page < 1) page = 1;
    if (perPage < 1) perPage = 15;
    if (perPage > 80) perPage = 80;
    
    final uri = Uri.parse('$_baseUrl$_curatedEndpoint')
        .replace(queryParameters: {
      'page': page.toString(),
      'per_page': perPage.toString(),
    });
    
    try {
      _recordRequest();
      final response = await http.get(uri, headers: _getHeaders())
          .timeout(const Duration(seconds: 30));
      
      return _handleResponse(response);
    } on TimeoutException {
      throw PexelsApiException(
        'Request timeout. Please check your internet connection.',
        408,
        PexelsErrorType.networkError,
      );
    } catch (e) {
      if (e is PexelsApiException) rethrow;
      throw PexelsApiException(
        'Network error: ${e.toString()}',
        null,
        PexelsErrorType.networkError,
      );
    }
  }
  
  /// Search photos by query
  /// 
  /// [query] - Search term (e.g., "nature", "landscape", "city")
  /// [page] - Page number (default: 1)
  /// [perPage] - Number of photos per page (default: 15, max: 80)
  /// [orientation] - Photo orientation: "landscape", "portrait", or "square"
  /// [size] - Photo size: "large", "medium", or "small"
  /// [color] - Photo color: "red", "orange", "yellow", "green", "turquoise", "blue", "violet", "pink", "brown", "black", "gray", "white"
  static Future<PexelsResponse> searchPhotos({
    required String query,
    int page = 1,
    int perPage = 15,
    String? orientation,
    String? size,
    String? color,
  }) async {
    if (!_isWithinRateLimit()) {
      throw PexelsApiException(
        'Rate limit exceeded. Please try again later.',
        429,
        PexelsErrorType.rateLimitExceeded,
      );
    }
    
    // Validate parameters
    if (query.trim().isEmpty) {
      throw ArgumentError('Search query cannot be empty');
    }
    if (page < 1) page = 1;
    if (perPage < 1) perPage = 15;
    if (perPage > 80) perPage = 80;
    
    final queryParameters = <String, String>{
      'query': query.trim(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    
    // Add optional parameters
    if (orientation != null && orientation.isNotEmpty) {
      queryParameters['orientation'] = orientation;
    }
    if (size != null && size.isNotEmpty) {
      queryParameters['size'] = size;
    }
    if (color != null && color.isNotEmpty) {
      queryParameters['color'] = color;
    }
    
    final uri = Uri.parse('$_baseUrl$_searchEndpoint')
        .replace(queryParameters: queryParameters);
    
    try {
      _recordRequest();
      final response = await http.get(uri, headers: _getHeaders())
          .timeout(const Duration(seconds: 30));
      
      return _handleResponse(response);
    } on TimeoutException {
      throw PexelsApiException(
        'Request timeout. Please check your internet connection.',
        408,
        PexelsErrorType.networkError,
      );
    } catch (e) {
      if (e is PexelsApiException) rethrow;
      throw PexelsApiException(
        'Network error: ${e.toString()}',
        null,
        PexelsErrorType.networkError,
      );
    }
  }
  
  /// Get a random photo from a specific category
  /// This is a convenience method that searches for photos and returns a random one
  static Future<PexelsPhoto?> getRandomPhotoByCategory(String category) async {
    try {
      final response = await searchPhotos(
        query: category,
        page: 1,
        perPage: 80, // Get more photos to have better randomization
        orientation: 'portrait', // Prefer portrait for mobile wallpapers
      );
      
      if (response.photos.isNotEmpty) {
        // Return a random photo from the results
        final randomIndex = DateTime.now().millisecondsSinceEpoch % response.photos.length;
        return response.photos[randomIndex];
      }
      
      return null;
    } catch (e) {
      // If search fails, try curated photos as fallback
      try {
        final curatedResponse = await fetchCuratedPhotos(perPage: 80);
        if (curatedResponse.photos.isNotEmpty) {
          final randomIndex = DateTime.now().millisecondsSinceEpoch % curatedResponse.photos.length;
          return curatedResponse.photos[randomIndex];
        }
      } catch (fallbackError) {
        // Re-throw original error if fallback also fails
        rethrow;
      }
      
      return null;
    }
  }
  
  /// Clear rate limit tracking (useful for testing)
  static void clearRateLimitTracking() {
    _requestTimes.clear();
  }
}

/// Custom exception for Pexels API errors
class PexelsApiException implements Exception {
  final String message;
  final int? statusCode;
  final PexelsErrorType type;
  
  PexelsApiException(this.message, this.statusCode, this.type);
  
  @override
  String toString() {
    return 'PexelsApiException: $message (Status: $statusCode, Type: $type)';
  }
}

/// Types of Pexels API errors
enum PexelsErrorType {
  networkError,
  rateLimitExceeded,
  invalidApiKey,
  serverError,
  noContent,
}