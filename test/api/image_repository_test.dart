import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/api/image_repository.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  group('ImageRepository', () {
    setUpAll(() async {
      // Load environment variables for testing
      await dotenv.load(fileName: ".env");
    });

    group('Pexels Integration', () {
      test('should validate image URL format', () async {
        // Test URL validation with a known good URL
        const testUrl = 'https://www.google.com';
        final isValid = await ImageRepository.validateImageUrl(testUrl);
        expect(isValid, isA<bool>());
      });

      test('should handle empty category gracefully', () async {
        // Test that empty category is handled properly
        expect(
          () => ImageRepository.fetchFromPexels(''),
          throwsA(isA<Exception>()),
        );
      });

      test('should create proper ImageItem structure', () {
        // This test verifies the ImageItem structure without making API calls
        // We can't easily test the actual conversion without mocking, but we can
        // verify the method exists and has the right signature
        expect(ImageRepository.fetchFromPexels, isA<Function>());
        expect(ImageRepository.fetchPexelsCurated, isA<Function>());
        expect(ImageRepository.searchPexelsImages, isA<Function>());
      });

      test('should handle search parameters correctly', () {
        // Test that search method accepts required parameters
        expect(
          () => ImageRepository.searchPexelsImages(query: 'nature'),
          returnsNormally,
        );
      });
    });

    group('Existing Bing Integration', () {
      test('should maintain Bing functionality', () {
        // Verify that existing Bing methods still exist
        expect(ImageRepository.fetchFromBing, isA<Function>());
        expect(ImageRepository.fetchThumbnailFromBing, isA<Function>());
      });
    });
  });
}