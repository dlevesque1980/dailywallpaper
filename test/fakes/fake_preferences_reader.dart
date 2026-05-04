import 'package:dailywallpaper/core/preferences/preferences_reader.dart';

class FakePreferencesReader implements PreferencesReader {
  final Map<String, dynamic> _store = {};

  void put(String key, dynamic value) {
    _store[key] = value;
  }

  @override
  Future<bool> getBool(String key) async => _store[key] as bool? ?? false;

  @override
  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> getBoolWithDefault(String key, bool defValue) async =>
      _store[key] as bool? ?? defValue;

  @override
  Future<String?> getString(String key) async => _store[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<String> getStringWithDefault(String key, String defValue) async =>
      _store[key] as String? ?? defValue;

  @override
  Future<List<String>?> getStringList(String key) async =>
      (_store[key] as List?)?.cast<String>();

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<List<String>> getStringListWithDefault(
      String key, List<String> defValue) async =>
      (_store[key] as List?)?.cast<String>() ?? defValue;

  @override
  Future<int?> getInt(String key) async => _store[key] as int?;

  @override
  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<int> getIntWithDefault(String key, int defValue) async =>
      _store[key] as int? ?? defValue;

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }
}
