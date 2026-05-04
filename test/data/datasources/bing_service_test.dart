import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/datasources/bing_service.dart';
import '../../fakes/fake_http_client.dart';

void main() {
  group('BingService', () {
    late FakeHttpClient client;
    late BingService service;

    setUp(() {
      client = FakeHttpClient();
      service = BingService(client: client);
    });

    test('fetchFromBing returns ImageItem on success', () async {
      client.fakeBody = json.encode({
        'images': [
          {
            'startdate': '20240503',
            'fullstartdate': '202405030700',
            'enddate': '20240504',
            'url': '/th?id=OHR.Test_EN-US1234567890_1920x1080.jpg',
            'urlbase': '/th?id=OHR.Test_EN-US1234567890',
            'copyright': 'Test Copyright (Photographer Name)',
            'copyrightlink': 'https://example.com',
            'quiz': 'quiz',
            'wp': true,
            'hsh': 'hash',
            'drk': 1,
            'top': 1,
            'bot': 1,
          }
        ]
      });

      final result = await service.fetchFromBing('en-US');

      expect(result.source, 'Bing image of the day');
      expect(result.url, contains('UHD'));
      expect(result.description, 'Test Copyright');
      expect(result.copyright, 'Photographer Name');
      expect(client.lastCalledUri.toString(), contains('mkt=en-US'));
    });

    test('fetchFromBing throws on 404', () async {
      client.fakeStatusCode = 404;
      expect(() => service.fetchFromBing('en-US'), throwsException);
    });
  });
}
