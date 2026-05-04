import 'dart:typed_data';
import 'package:dailywallpaper/services/wallpaper/wallpaper_service.dart';

class FakeWallpaperService implements WallpaperService {
  String? lastSetUrl;
  Uint8List? lastSetBytes;
  String returnMessage = 'Wallpaper set successfully';
  bool shouldThrow = false;
  String throwMessage = 'Wallpaper error';

  @override
  Future<String?> setBothWallpaper(String url) async {
    if (shouldThrow) throw Exception(throwMessage);
    lastSetUrl = url;
    return returnMessage;
  }

  @override
  Future<String?> setSystemWallpaper(String url) async {
    if (shouldThrow) throw Exception(throwMessage);
    lastSetUrl = url;
    return returnMessage;
  }

  @override
  Future<String?> setBothWallpaperFromBytes(Uint8List bytes) async {
    if (shouldThrow) throw Exception(throwMessage);
    lastSetBytes = bytes;
    return returnMessage;
  }

  @override
  Future<String?> setSystemWallpaperFromBytes(Uint8List bytes) async {
    if (shouldThrow) throw Exception(throwMessage);
    lastSetBytes = bytes;
    return returnMessage;
  }
}
