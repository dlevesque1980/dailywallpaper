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

  static Future<bool> getBoolWithDefault(String key, bool defValue) async {
    final p = await prefs;
    final value = p.getBool(key);
    if (value != null) return value;
    await p.setBool(key, defValue);
    return defValue;
  }

  static Future<String?> getString(String key) async {
    final p = await prefs;
    return p.getString(key);
  }

  static Future<bool> setString(String key, String value) async {
    final p = await prefs;
    return p.setString(key, value);
  }

  static Future<String> getStringWithDefault(
      String key, String defValue) async {
    var val = await getString(key);
    if (val != null) return val;

    await setString(key, defValue);
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

  static Future<List<String>> getStringListWithDefault(
      String key, List<String> defValue) async {
    var val = await getStringList(key);
    if (val != null) return val;

    await setStringList(key, defValue);
    return defValue;
  }

  static Future<int?> getInt(String key) async {
    final p = await prefs;
    return p.getInt(key);
  }

  static Future<bool> setInt(String key, int value) async {
    final p = await prefs;
    return p.setInt(key, value);
  }

  static Future<int> getIntWithDefault(String key, int defValue) async {
    var val = await getInt(key);
    if (val != null) return val;

    await setInt(key, defValue);
    return defValue;
  }

  static Future<bool> remove(String key) async {
    final p = await prefs;
    return p.remove(key);
  }
}
