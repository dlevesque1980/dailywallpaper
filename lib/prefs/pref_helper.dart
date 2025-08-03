import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class PrefHelper {
  static Future<SharedPreferences> get prefs => SharedPreferences.getInstance();


  static Future<bool> getBool(String key) async {
    final p = await prefs;
    return p.getBool(key) ?? false;
  }

  static Future<bool> setBool(String key, bool value) async {
    final p = await prefs;
    return p.setBool(key, value);
  }

  static bool setDefaultBoolValue(String key, bool val) {
    setBool(key,val);
    return val;
  }

  static Future<bool> getBoolWithDefault(String key, bool defValue) async {
    var p = await prefs;
    var val = await p.getBool(key) ?? setDefaultBoolValue(key, defValue);
    return val;
  }

  static Future<String?> getString(String key) async {
    final p = await prefs;
    return p.getString(key);
  }

  static Future<bool> setString(String key, String value) async {
    final p = await prefs;
    return p.setString(key, value);
  }

  static Future<String> getStringWithDefault(String key, String defValue) async {
    var val = await getString(key);
    if (val != null) return val;

    setString(key, defValue);
    return defValue;
  }

  static Future<List<String>?> getStringList(String key) async {
    final p = await prefs;
    return p.getStringList(key);
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    final p = await prefs;
    return p.setStringList(key, value);
  }

  static Future<List<String>> getStringListWithDefault(String key, List<String> defValue) async {
    var val = await getStringList(key);
    if (val != null) return val;

    setStringList(key, defValue);
    return defValue;
  }
}
