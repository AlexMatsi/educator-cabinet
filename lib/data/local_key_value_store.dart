import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesStore implements LocalKeyValueStore {
  const SharedPreferencesStore();

  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(key, value);
    if (!saved) {
      throw StateError('shared_preferences не підтвердив запис.');
    }
  }
}
