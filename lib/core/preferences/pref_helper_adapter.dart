import 'package:dailywallpaper/core/preferences/pref_helper.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';

class PrefHelperAdapter implements PreferencesReader {
  @override
  Future<bool> getBool(String key) => PrefHelper.getBool(key);

  @override
  Future<bool> setBool(String key, bool value) => PrefHelper.setBool(key, value);

  @override
  Future<bool> getBoolWithDefault(String key, bool defValue) => PrefHelper.getBoolWithDefault(key, defValue);

  @override
  Future<String?> getString(String key) => PrefHelper.getString(key);

  @override
  Future<bool> setString(String key, String value) => PrefHelper.setString(key, value);

  @override
  Future<String> getStringWithDefault(String key, String defValue) => PrefHelper.getStringWithDefault(key, defValue);

  @override
  Future<List<String>?> getStringList(String key) => PrefHelper.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) => PrefHelper.setStringList(key, value);

  @override
  Future<List<String>> getStringListWithDefault(String key, List<String> defValue) => PrefHelper.getStringListWithDefault(key, defValue);

  @override
  Future<int?> getInt(String key) => PrefHelper.getInt(key);

  @override
  Future<bool> setInt(String key, int value) => PrefHelper.setInt(key, value);

  @override
  Future<int> getIntWithDefault(String key, int defValue) => PrefHelper.getIntWithDefault(key, defValue);

  @override
  Future<bool> remove(String key) => PrefHelper.remove(key);
}
