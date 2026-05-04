abstract class PreferencesReader {
  Future<bool> getBool(String key);
  Future<bool> setBool(String key, bool value);
  Future<bool> getBoolWithDefault(String key, bool defValue);
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
  Future<String> getStringWithDefault(String key, String defValue);
  Future<List<String>?> getStringList(String key);
  Future<bool> setStringList(String key, List<String> value);
  Future<List<String>> getStringListWithDefault(String key, List<String> defValue);
  Future<int?> getInt(String key);
  Future<bool> setInt(String key, int value);
  Future<int> getIntWithDefault(String key, int defValue);
  Future<bool> remove(String key);
}
