import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dailywallpaper/data/models/nasa/nasa_models.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:dailywallpaper/data/datasources/nasa_data_source.dart';

class NasaService implements NasaDataSource {
  static const String _baseUrl = 'https://api.nasa.gov/planetary/apod';
  static const int _timeoutSeconds = 5;
  
  static DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 100);

  final http.Client _client;

  NasaService({http.Client? client}) : _client = client ?? http.Client();

  String get _apiKey => dotenv.env['NASA_API_KEY'] ?? 'DEMO_KEY';

  @override
  Future<ImageItem> fetchFromNASA() async {
    await _enforceRateLimit();
    
    final uri = Uri.parse('$_baseUrl?api_key=$_apiKey');
    
    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final nasaResponse = NASAResponse.fromJson(data);
        
        if (!nasaResponse.isImage) {
          throw NASAException(
            'Today\'s NASA APOD is not an image (it\'s a ${nasaResponse.mediaType})',
            response.statusCode,
            NASAErrorType.noContent,
          );
        }
        
        return _convertNASAResponseToImageItem(nasaResponse);
      } else {
        throw _handleError(response);
      }
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<ImageItem> fetchNASAByDate(String date) async {
    await _enforceRateLimit();
    
    final uri = Uri.parse('$_baseUrl?api_key=$_apiKey&date=$date');
    
    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final nasaResponse = NASAResponse.fromJson(data);

        if (!nasaResponse.isImage) {
          throw NASAException(
            'NASA APOD for $date is not an image (it\'s a ${nasaResponse.mediaType})',
            response.statusCode,
            NASAErrorType.noContent,
          );
        }

        return _convertNASAResponseToImageItem(nasaResponse);
      } else {
        throw _handleError(response, context: 'date $date');
      }
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<List<ImageItem>> fetchNASAArchive({int days = 7}) async {
    await _enforceRateLimit();
    
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: days));

    final startDateStr = _formatDateForNASA(startDate);
    final endDateStr = _formatDateForNASA(endDate);

    final uri = Uri.parse(
      '$_baseUrl?api_key=$_apiKey&start_date=$startDateStr&end_date=$endDateStr'
    );
    
    try {
      final response = await _client.get(uri).timeout(
        const Duration(seconds: _timeoutSeconds),
      );

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        List<ImageItem> results = [];
        
        if (data is List) {
          for (var item in data) {
            final nasaResponse = NASAResponse.fromJson(item);
            if (nasaResponse.isImage) {
              results.add(_convertNASAResponseToImageItem(nasaResponse));
              if (results.length >= days) break;
            }
          }
        }
        return results;
      } else {
        throw _handleError(response, context: 'range');
      }
    } catch (e) {
      throw _wrapError(e);
    }
  }

  ImageItem _convertNASAResponseToImageItem(NASAResponse nasaResponse) {
    final date = DateTime.parse(nasaResponse.date);
    final startTime = DateTimeHelper.startDayDate(date);
    final endTime = startTime.add(const Duration(days: 1));

    final description = nasaResponse.title.isNotEmpty
        ? nasaResponse.title
        : nasaResponse.explanation.length > 100
            ? '${nasaResponse.explanation.substring(0, 100)}...'
            : nasaResponse.explanation;

    return ImageItem(
      "NASA APOD",
      nasaResponse.bestImageUrl,
      description,
      startTime.toUtc(),
      endTime.toUtc(),
      'nasa.${nasaResponse.date}',
      null,
      nasaResponse.attribution,
    );
  }

  String _formatDateForNASA(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  NASAException _handleError(http.Response response, {String? context}) {
    final message = context != null 
        ? 'Failed to fetch NASA APOD for $context: ${response.statusCode}'
        : 'Failed to fetch NASA APOD: ${response.statusCode}';

    NASAErrorType type = NASAErrorType.serverError;
    if (response.statusCode == 429) type = NASAErrorType.rateLimitExceeded;
    if (response.statusCode == 403) type = NASAErrorType.invalidApiKey;
    if (response.statusCode == 400) type = NASAErrorType.invalidDate;

    return NASAException(message, response.statusCode, type);
  }

  Exception _wrapError(dynamic e) {
    if (e is NASAException) return e;
    return NASAException('Network error: ${e.toString()}', null, NASAErrorType.networkError);
  }

  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - timeSinceLastRequest);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}

class NASAException implements Exception {
  final String message;
  final int? statusCode;
  final NASAErrorType type;

  NASAException(this.message, this.statusCode, this.type);

  @override
  String toString() => 'NASAException: $message (Status: $statusCode, Type: $type)';
}

enum NASAErrorType {
  networkError,
  rateLimitExceeded,
  invalidApiKey,
  invalidDate,
  noContent,
  serverError,
}
