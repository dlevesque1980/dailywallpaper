import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/datasources/nasa_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../fakes/fake_http_client.dart';

void main() {
  group('NasaService', () {
    late FakeHttpClient client;
    late NasaService service;

    setUp(() {
      dotenv.testLoad(fileInput: 'NASA_API_KEY=test_key');
      client = FakeHttpClient();
      service = NasaService(client: client);
    });

    test('fetchFromNASA returns ImageItem', () async {
      client.fakeBody = json.encode({
        'title': 'NASA Title',
        'url': 'https://nasa.gov/image.jpg',
        'explanation': 'NASA Explains',
        'date': '2024-05-03',
        'media_type': 'image',
        'hdurl': 'https://nasa.gov/hd.jpg',
      });

      final result = await service.fetchFromNASA();

      expect(result.description, contains('NASA'));
      expect(result.url, contains('hd.jpg'));
    });

    test('fetchFromNASA throws on non-image media', () async {
      client.fakeBody = json.encode({
        'media_type': 'video',
      });

      expect(() => service.fetchFromNASA(), throwsException);
    });
  });
}
