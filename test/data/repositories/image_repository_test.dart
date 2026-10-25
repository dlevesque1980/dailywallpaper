import 'dart:convert';

import 'package:dailywallpaper/data/datasources/supabase_wallpaper_data_source.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_client.dart';

void main() {
  group('ImageRepository', () {
    test('loads the records belonging to the newest available date', () async {
      final client = FakeHttpClient(
        fakeBody: jsonEncode([
          {
            'id': 'today-1',
            'date': '2026-10-25',
            'source': 'service',
            'image_url': 'https://res.cloudinary.com/example/image.avif',
            'created_at': '2026-10-25T08:00:00Z',
            'title': 'Today',
            'category': 'portrait',
            'credit': null,
            'source_url': null,
            'cloudinary': {'format': 'avif'},
            'focal': null,
            'crop_strategy': null,
            'crop': null,
            'generated_at': null,
            'settings_hash': null,
          },
          {
            'id': 'today-2',
            'date': '2026-10-25',
            'source': 'service',
            'image_url': 'https://res.cloudinary.com/example/today-2.avif',
            'created_at': '2026-10-25T07:00:00Z',
          },
          {
            'id': 'yesterday',
            'date': '2026-10-24',
            'source': 'service',
            'image_url': 'https://res.cloudinary.com/example/old.avif',
            'created_at': '2026-10-24T07:00:00Z',
          },
        ]),
      );
      final repository = ImageRepository(
        dataSource: SupabaseWallpaperDataSource(
          client: client,
          apiKey: 'sb_publishable_test-key',
        ),
      );

      final images = await repository.fetchLatestWallpapers();

      expect(images.map((image) => image.id), ['today-1', 'today-2']);
      expect(images.first.imageUrl, contains('.avif'));
      expect(images.first.category, 'portrait');
      expect(images.first.cloudinary, {'format': 'avif'});
      expect(client.lastCalledUri?.host, 'ncfpyfwvawyyyiqfpzwk.supabase.co');
      expect(client.lastCalledUri?.path, '/rest/v1/wallpapers');
      expect(
        client.lastCalledHeaders?['apikey'],
        'sb_publishable_test-key',
      );
      expect(client.lastCalledHeaders?.containsKey('Authorization'), isFalse);
    });

    test('orders daily images by source and Pexels selector category order',
        () async {
      final client = FakeHttpClient(
        fakeBody: jsonEncode([
          _wallpaperRow(
            id: 'nasa',
            source: 'nasa',
            category: null,
          ),
          _wallpaperRow(
            id: 'nature',
            source: 'pexels',
            category: 'nature',
          ),
          _wallpaperRow(
            id: 'bing',
            source: 'bing',
            category: null,
          ),
          _wallpaperRow(
            id: 'animals',
            source: 'pexels',
            category: 'animals',
          ),
          _wallpaperRow(
            id: 'portrait',
            source: 'pexels',
            category: 'portrait',
          ),
        ]),
      );
      final repository = ImageRepository(
        dataSource: SupabaseWallpaperDataSource(
          client: client,
          apiKey: 'sb_publishable_test-key',
        ),
      );

      final images = await repository.fetchLatestWallpapers();

      expect(
        images.map((image) => image.id),
        ['bing', 'portrait', 'animals', 'nature', 'nasa'],
      );
      expect(images.first.displayTitle, 'Bing Daily Image');
      expect(images[1].displayTitle, 'Pexel portrait');
      expect(images.last.displayTitle, 'NASA APOD');
      expect(images.first.category, isNull);
      expect(images.last.category, isNull);
    });

    test('surfaces Supabase HTTP errors', () async {
      final repository = ImageRepository(
        dataSource: SupabaseWallpaperDataSource(
          client: FakeHttpClient(
            fakeBody: '{"message":"not allowed"}',
            fakeStatusCode: 403,
          ),
          apiKey: 'sb_publishable_test-key',
        ),
      );

      await expectLater(
        repository.fetchLatestWallpapers(),
        throwsA(isA<SupabaseWallpaperException>()),
      );
    });

    test('fails clearly when the publishable key is missing', () async {
      final repository = ImageRepository(
        dataSource: SupabaseWallpaperDataSource(
          client: FakeHttpClient(),
          apiKey: '',
        ),
      );

      await expectLater(
        repository.fetchLatestWallpapers(),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects secret keys without sending a request', () async {
      final client = FakeHttpClient(fakeBody: '[]');
      final repository = ImageRepository(
        dataSource: SupabaseWallpaperDataSource(
          client: client,
          apiKey: 'sb_secret_test-key',
        ),
      );

      await expectLater(
        repository.fetchLatestWallpapers(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Secret keys must stay on a trusted server'),
          ),
        ),
      );
      expect(client.lastCalledUri, isNull);
    });

    test('queries history by date and returns distinct available dates',
        () async {
      final client = FakeHttpClient(
        fakeBody: jsonEncode([
          {
            'id': 'history-1',
            'date': '2026-10-24',
            'source': 'service',
            'image_url': 'https://res.cloudinary.com/example/history.avif',
            'created_at': '2026-10-24T07:00:00Z',
          },
          {
            'id': 'history-2',
            'date': '2026-10-24',
            'source': 'service',
            'image_url': 'https://res.cloudinary.com/example/history-2.avif',
            'created_at': '2026-10-24T06:00:00Z',
          },
        ]),
      );
      final repository = ImageRepository(
        dataSource: SupabaseWallpaperDataSource(
          client: client,
          apiKey: 'sb_publishable_test-key',
        ),
      );

      final images = await repository.fetchWallpapersForDate(
        DateTime(2026, 10, 24),
      );
      expect(images.map((image) => image.id), ['history-1', 'history-2']);
      expect(
        client.lastCalledUri?.queryParameters['date'],
        'eq.2026-10-24',
      );

      client.fakeBody = jsonEncode([
        {'date': '2026-10-25'},
        {'date': '2026-10-24'},
        {'date': '2026-10-24'},
      ]);
      final dates = await repository.fetchAvailableDates();
      expect(dates.map((date) => date.toIso8601String().substring(0, 10)), [
        '2026-10-25',
        '2026-10-24',
      ]);
    });
  });
}

Map<String, Object?> _wallpaperRow({
  required String id,
  required String source,
  required String? category,
}) {
  return {
    'id': id,
    'date': '2026-10-25',
    'source': source,
    'category': category,
    'image_url': 'https://res.cloudinary.com/example/$id.avif',
    'created_at': '2026-10-25T08:00:00Z',
  };
}
