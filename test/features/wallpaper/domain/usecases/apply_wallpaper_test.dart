import 'dart:io';

import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_http_client.dart';
import '../../../../fakes/fake_preferences_reader.dart';
import '../../../../fakes/fake_wallpaper_service.dart';

void main() {
  late FakeWallpaperService wallpaperService;
  late FakePreferencesReader preferences;
  late FakeHttpClient client;
  late ApplyWallpaperUseCase useCase;

  final image = ImageItem(
    id: 'daily-wallpaper',
    date: DateTime(2026, 10, 25),
    source: 'external-service',
    imageUrl: 'https://res.cloudinary.com/example/daily.avif',
    createdAt: DateTime.utc(2026, 10, 25),
  );

  setUp(() {
    wallpaperService = FakeWallpaperService();
    preferences = FakePreferencesReader();
    client = FakeHttpClient(fakeBody: 'avif-image-bytes');
    useCase = ApplyWallpaperUseCase(
      wallpaperService: wallpaperService,
      prefHelper: preferences,
      client: client,
    );
  });

  test('downloads the ready image URL and applies its bytes to both screens',
      () async {
    final result = await useCase(image);

    expect(result, 'wallpaperSetSuccess');
    expect(client.lastCalledUri, Uri.parse(image.imageUrl));
    expect(
      wallpaperService.lastSetBytes,
      'avif-image-bytes'.codeUnits,
    );
    expect(wallpaperService.lastIncludedLockScreen, isTrue);
  });

  test('keeps the lock-screen preference for system-only wallpaper', () async {
    await preferences.setBool(includeLockWallpaperPreference, false);

    await useCase(image);

    expect(wallpaperService.lastSetBytes, isNotNull);
    expect(wallpaperService.lastIncludedLockScreen, isFalse);
  });

  test('surfaces a failed image download', () async {
    client.fakeStatusCode = 404;

    await expectLater(
      useCase(image),
      throwsA(isA<HttpException>()),
    );
  });

  test('rejects a non-HTTP image URL', () async {
    final invalidImage = ImageItem(
      id: image.id,
      date: image.date,
      source: image.source,
      imageUrl: 'file:///tmp/wallpaper.avif',
      createdAt: image.createdAt,
    );

    await expectLater(useCase(invalidImage), throwsFormatException);
  });
}
