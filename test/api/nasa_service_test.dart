import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dailywallpaper/api/nasa_service.dart';

void main() {
  group('NASAService', () {
    setUpAll(() async {
      // Load environment variables for testing
      await dotenv.load(fileName: '.env');
    });

    test('should handle NASAException correctly', () {
      final exception = NASAException(
        'Test error',
        400,
        NASAErrorType.invalidDate,
      );

      expect(exception.message, 'Test error');
      expect(exception.statusCode, 400);
      expect(exception.type, NASAErrorType.invalidDate);
      expect(exception.toString(), contains('NASAException: Test error'));
    });

    test('should have environment variables loaded', () {
      // This test verifies the service configuration without making actual API calls
      expect(dotenv.env['NASA_API_KEY'], isNotNull);
    });

    // Note: We're not testing actual API calls here to avoid hitting rate limits
    // and to keep tests fast and reliable. In a real scenario, you would:
    // 1. Mock the HTTP client
    // 2. Test with fake responses
    // 3. Test error handling scenarios
    // 4. Test rate limiting behavior
  });
}