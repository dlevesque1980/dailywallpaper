import 'dart:typed_data';
import 'dart:io';

import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/services/wallpaper/wallpaper_service.dart';
import 'package:http/http.dart' as http;

class ApplyWallpaperUseCase {
  ApplyWallpaperUseCase({
    WallpaperService? wallpaperService,
    PreferencesReader? prefHelper,
    http.Client? client,
  })  : _wallpaperService = wallpaperService ?? WallpaperServiceImpl(),
        _prefHelper = prefHelper ?? PrefHelperAdapter(),
        _client = client ?? http.Client();

  final WallpaperService _wallpaperService;
  final PreferencesReader _prefHelper;
  final http.Client _client;

  Future<String> call(ImageItem image) async {
    final uri = Uri.tryParse(image.imageUrl);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw FormatException('Invalid wallpaper URL: ${image.imageUrl}');
    }

    final response =
        await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Wallpaper download returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    if (response.bodyBytes.isEmpty) {
      throw const FormatException('Wallpaper download returned no image data.');
    }

    final includeLock = await _prefHelper.getBoolWithDefault(
        includeLockWallpaperPreference, true);
    final Uint8List bytes = response.bodyBytes;
    final message = includeLock
        ? await _wallpaperService.setBothWallpaperFromBytes(bytes)
        : await _wallpaperService.setSystemWallpaperFromBytes(bytes);

    if (message == null || message.isEmpty) {
      throw StateError('Wallpaper service returned no result.');
    }
    return _normalizeMessage(message);
  }

  String _normalizeMessage(String message) {
    if (message == 'Success' ||
        message.toLowerCase().startsWith('wallpaper set')) {
      return 'wallpaperSetSuccess';
    }
    return message;
  }
}
