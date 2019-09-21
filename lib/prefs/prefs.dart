import 'dart:async';
import 'package:dailywallpaper/prefs/pref_consts.dart';

import 'package:dailywallpaper/prefs/pref_helper.dart';

class Prefs {
  static bool _includeLockWallpaper = true;
  static String _bingRegion = 'en-US';
  static List<String> _unsplashCategories = ["nature"];

  static Future<bool> get includeLockWallpaper => PrefHelper.getBoolWithDefault(sp_IncludeLockWallpaper, _includeLockWallpaper);
  static set includeLockWallpaper(bool value) => PrefHelper.setBool(sp_IncludeLockWallpaper, value);

  static Future<String> get bingRegion => PrefHelper.getStringWithDefault(sp_BingRegion, _bingRegion);
  static set bingRegion(String value) => PrefHelper.setString(sp_BingRegion, value);

  static Future<List<String>> get unsplashCategories => PrefHelper.getStringListWithDefault(sp_Unspaslh_Categories, _unsplashCategories);
  static set unsplashCategories(List<String> value) => PrefHelper.setStringList(sp_Unspaslh_Categories, value);
}
