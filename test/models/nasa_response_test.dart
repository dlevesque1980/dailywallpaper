import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/models/nasa/nasa_response.dart';

void main() {
  group('NASAResponse', () {
    test('should create NASAResponse from JSON with all fields', () {
      final json = {
        'date': '2024-01-15',
        'explanation': 'A beautiful nebula in space',
        'hdurl': 'https://apod.nasa.gov/apod/image/2401/nebula_hd.jpg',
        'media_type': 'image',
        'service_version': 'v1',
        'title': 'Beautiful Nebula',
        'url': 'https://apod.nasa.gov/apod/image/2401/nebula.jpg',
        'copyright': 'NASA/ESA'
      };

      final response = NASAResponse.fromJson(json);

      expect(response.date, '2024-01-15');
      expect(response.explanation, 'A beautiful nebula in space');
      expect(response.hdurl, 'https://apod.nasa.gov/apod/image/2401/nebula_hd.jpg');
      expect(response.mediaType, 'image');
      expect(response.title, 'Beautiful Nebula');
      expect(response.copyright, 'NASA/ESA');
      expect(response.isImage, true);
    });

    test('should handle missing optional fields', () {
      final json = {
        'date': '2024-01-15',
        'explanation': 'A video of space',
        'media_type': 'video',
        'service_version': 'v1',
        'title': 'Space Video',
        'url': 'https://apod.nasa.gov/apod/video/space.mp4',
      };

      final response = NASAResponse.fromJson(json);

      expect(response.hdurl, null);
      expect(response.copyright, null);
      expect(response.isImage, false);
      expect(response.mediaType, 'video');
    });

    test('should return correct best image URL', () {
      // Test with hdurl available
      final responseWithHd = NASAResponse.fromJson({
        'date': '2024-01-15',
        'explanation': 'Test',
        'hdurl': 'https://example.com/hd.jpg',
        'media_type': 'image',
        'service_version': 'v1',
        'title': 'Test',
        'url': 'https://example.com/regular.jpg',
      });

      expect(responseWithHd.bestImageUrl, 'https://example.com/hd.jpg');

      // Test without hdurl
      final responseWithoutHd = NASAResponse.fromJson({
        'date': '2024-01-15',
        'explanation': 'Test',
        'media_type': 'image',
        'service_version': 'v1',
        'title': 'Test',
        'url': 'https://example.com/regular.jpg',
      });

      expect(responseWithoutHd.bestImageUrl, 'https://example.com/regular.jpg');
    });

    test('should create proper attribution', () {
      // Test with copyright
      final responseWithCopyright = NASAResponse.fromJson({
        'date': '2024-01-15',
        'explanation': 'Test',
        'media_type': 'image',
        'service_version': 'v1',
        'title': 'Test',
        'url': 'https://example.com/image.jpg',
        'copyright': 'NASA/ESA/Hubble'
      });

      expect(responseWithCopyright.attribution, 'Image courtesy of NASA - NASA/ESA/Hubble');

      // Test without copyright
      final responseWithoutCopyright = NASAResponse.fromJson({
        'date': '2024-01-15',
        'explanation': 'Test',
        'media_type': 'image',
        'service_version': 'v1',
        'title': 'Test',
        'url': 'https://example.com/image.jpg',
      });

      expect(responseWithoutCopyright.attribution, 'Image courtesy of NASA');
    });

    test('should serialize to JSON correctly', () {
      final response = NASAResponse(
        date: '2024-01-15',
        explanation: 'Test explanation',
        hdurl: 'https://example.com/hd.jpg',
        mediaType: 'image',
        serviceVersion: 'v1',
        title: 'Test Title',
        url: 'https://example.com/regular.jpg',
        copyright: 'NASA',
      );

      final json = response.toJson();

      expect(json['date'], '2024-01-15');
      expect(json['explanation'], 'Test explanation');
      expect(json['hdurl'], 'https://example.com/hd.jpg');
      expect(json['media_type'], 'image');
      expect(json['service_version'], 'v1');
      expect(json['title'], 'Test Title');
      expect(json['url'], 'https://example.com/regular.jpg');
      expect(json['copyright'], 'NASA');
    });
  });
}