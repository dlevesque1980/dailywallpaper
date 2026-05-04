import 'dart:typed_data';
import 'package:setwallpaper/setwallpaper.dart';

/// Service interface for setting wallpapers
abstract class WallpaperService {
  /// Set wallpaper on both home and lock screens from a URL
  Future<String?> setBothWallpaper(String url);

  /// Set wallpaper only on the home screen from a URL
  Future<String?> setSystemWallpaper(String url);

  /// Set wallpaper on both home and lock screens from image bytes
  Future<String?> setBothWallpaperFromBytes(Uint8List bytes);

  /// Set wallpaper only on the home screen from image bytes
  Future<String?> setSystemWallpaperFromBytes(Uint8List bytes);
}

/// Implementation of the WallpaperService using the setwallpaper plugin
class WallpaperServiceImpl implements WallpaperService {
  @override
  Future<String?> setBothWallpaper(String url) async {
    return await Setwallpaper.instance.setBothWallpaper(url);
  }

  @override
  Future<String?> setSystemWallpaper(String url) async {
    return await Setwallpaper.instance.setSystemWallpaper(url);
  }

  @override
  Future<String?> setBothWallpaperFromBytes(Uint8List bytes) async {
    return await Setwallpaper.instance.setBothWallpaperFromBytes(bytes);
  }

  @override
  Future<String?> setSystemWallpaperFromBytes(Uint8List bytes) async {
    return await Setwallpaper.instance.setSystemWallpaperFromBytes(bytes);
  }
}
