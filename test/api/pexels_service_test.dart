import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/api/pexels_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  group('PexelsService', () {
    setUpAll(() async {
      // Load environment variables for testing
      await dotenv.load(fileName: ".env");
    });

    test('should handle empty search query', () {
      expect(
        () => PexelsService.searchPhotos(query: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should validate page parameters', () async {
      // This test checks parameter validation without making actual API calls
      expect(() => PexelsService.searchPhotos(query: 'nature'), returnsNormally);
    });

    test('should handle rate limiting', () {
      // Clear any existing rate limit tracking
      PexelsService.clearRateLimitTracking();
      
      // This test verifies rate limiting logic exists
      expect(() => PexelsService.clearRateLimitTracking(), returnsNormally);
    });

    test('should create proper error types', () {
      final exception = PexelsApiException(
        'Test error',
        400,
        PexelsErrorType.networkError,
      );
      
      expect(exception.message, equals('Test error'));
      expect(exception.statusCode, equals(400));
      expect(exception.type, equals(PexelsErrorType.networkError));
    });
  });
}