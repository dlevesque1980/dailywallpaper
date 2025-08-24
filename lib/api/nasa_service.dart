import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/nasa/nasa_models.dart';

class NASAService {
  static const String _baseUrl = 'https://api.nasa.gov/planetary/apod';
  static const int _timeoutSeconds = 30;
  
  // Rate limiting: NASA allows 1000 requests/hour
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 100);

  static String get _apiKey => dotenv.env['NASA_API_KEY'] ?? 'DEMO_KEY';

  /// Fetch NASA Astronomy Picture of the Day for current date
  static Future<NASAResponse> fetchAPOD() async {
    await _enforceRateLimit();
    
    final uri = Uri.parse('$_baseUrl?api_key=$_apiKey');
    
    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return NASAResponse.fromJson(data);
      } else if (response.statusCode == 429) {
        throw NASAException(
          'Rate limit exceeded. Please try again later.',
          response.statusCode,
          NASAErrorType.rateLimitExceeded,
        );
      } else if (response.statusCode == 403) {
        throw NASAException(
          'Invalid API key or access denied.',
          response.statusCode,
          NASAErrorType.invalidApiKey,
        );
      } else {
        throw NASAException(
          'Failed to fetch NASA APOD: ${response.statusCode}',
          response.statusCode,
          NASAErrorType.serverError,
        );
      }
    } catch (e) {
      if (e is NASAException) {
        rethrow;
      }
      throw NASAException(
        'Network error: ${e.toString()}',
        null,
        NASAErrorType.networkError,
      );
    }
  }

  /// Fetch NASA APOD for a specific date
  /// [date] should be in format 'YYYY-MM-DD'
  static Future<NASAResponse> fetchAPODByDate(String date) async {
    await _enforceRateLimit();
    
    final uri = Uri.parse('$_baseUrl?api_key=$_apiKey&date=$date');
    
    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return NASAResponse.fromJson(data);
      } else if (response.statusCode == 400) {
        throw NASAException(
          'Invalid date format or date out of range.',
          response.statusCode,
          NASAErrorType.invalidDate,
        );
      } else if (response.statusCode == 429) {
        throw NASAException(
          'Rate limit exceeded. Please try again later.',
          response.statusCode,
          NASAErrorType.rateLimitExceeded,
        );
      } else if (response.statusCode == 403) {
        throw NASAException(
          'Invalid API key or access denied.',
          response.statusCode,
          NASAErrorType.invalidApiKey,
        );
      } else {
        throw NASAException(
          'Failed to fetch NASA APOD for date $date: ${response.statusCode}',
          response.statusCode,
          NASAErrorType.serverError,
        );
      }
    } catch (e) {
      if (e is NASAException) {
        rethrow;
      }
      throw NASAException(
        'Network error: ${e.toString()}',
        null,
        NASAErrorType.networkError,
      );
    }
  }

  /// Fetch multiple NASA APODs for a date range
  /// Returns only images (filters out videos)
  static Future<List<NASAResponse>> fetchAPODRange({
    required String startDate,
    required String endDate,
    int maxImages = 10,
  }) async {
    await _enforceRateLimit();
    
    final uri = Uri.parse(
      '$_baseUrl?api_key=$_apiKey&start_date=$startDate&end_date=$endDate'
    );
    
    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        List<NASAResponse> results = [];
        
        if (data is List) {
          for (var item in data) {
            final nasaResponse = NASAResponse.fromJson(item);
            // Only include images, skip videos
            if (nasaResponse.isImage) {
              results.add(nasaResponse);
              if (results.length >= maxImages) break;
            }
          }
        } else if (data is Map<String, dynamic>) {
          // Single item response
          final nasaResponse = NASAResponse.fromJson(data);
          if (nasaResponse.isImage) {
            results.add(nasaResponse);
          }
        }
        
        return results;
      } else if (response.statusCode == 400) {
        throw NASAException(
          'Invalid date range or parameters.',
          response.statusCode,
          NASAErrorType.invalidDate,
        );
      } else if (response.statusCode == 429) {
        throw NASAException(
          'Rate limit exceeded. Please try again later.',
          response.statusCode,
          NASAErrorType.rateLimitExceeded,
        );
      } else {
        throw NASAException(
          'Failed to fetch NASA APOD range: ${response.statusCode}',
          response.statusCode,
          NASAErrorType.serverError,
        );
      }
    } catch (e) {
      if (e is NASAException) {
        rethrow;
      }
      throw NASAException(
        'Network error: ${e.toString()}',
        null,
        NASAErrorType.networkError,
      );
    }
  }

  /// Enforce rate limiting to respect NASA API limits
  static Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}

/// Custom exception class for NASA API errors
class NASAException implements Exception {
  final String message;
  final int? statusCode;
  final NASAErrorType type;

  NASAException(this.message, this.statusCode, this.type);

  @override
  String toString() {
    return 'NASAException: $message (Status: $statusCode, Type: $type)';
  }
}

enum NASAErrorType {
  networkError,
  rateLimitExceeded,
  invalidApiKey,
  invalidDate,
  noContent,
  serverError,
}