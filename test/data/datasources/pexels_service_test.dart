import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/datasources/pexels_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../fakes/fake_http_client.dart';

void main() {
  group('PexelsService', () {
    late FakeHttpClient client;
    late PexelsService service;

    setUp(() async {
      dotenv.testLoad(fileInput: 'PEXELS_API_KEY=test_key');
      client = FakeHttpClient();
      service = PexelsService(client: client);
    });

    test('fetchPexelsCurated returns list of items', () async {
      client.fakeBody = json.encode({
        'photos': [
          {
            'id': 1,
            'photographer': 'Photog',
            'photographer_url': 'https://photog.com',
            'src': {
              'original': 'https://pexels.com/orig.jpg',
              'large2x': 'https://pexels.com/large2x.jpg',
            },
            'alt': 'Alt text'
          }
        ]
      });

      final result = await service.fetchPexelsCurated();

      expect(result.length, 1);
      expect(result.first.copyright, contains('Photog'));
      expect(client.lastCalledHeaders?['Authorization'], 'test_key');
    });
  });
}
