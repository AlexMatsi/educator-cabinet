import 'package:shared_preferences/shared_preferences.dart';

import '../models/student_data.dart';
import 'demo_repository.dart';
import 'student_data_codec.dart';
import 'student_repository.dart';

class SharedPreferencesStudentRepository implements StudentRepository {
  SharedPreferencesStudentRepository({required SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'student_data';

  final SharedPreferences? _preferences;
  final StudentDataCodec _codec = const StudentDataCodec();

  static Future<SharedPreferencesStudentRepository> create() async {
    try {
      return SharedPreferencesStudentRepository(
        preferences: await SharedPreferences.getInstance(),
      );
    } catch (_) {
      return SharedPreferencesStudentRepository(preferences: null);
    }
  }

  @override
  Future<StudentData> load() async {
    final preferences = _preferences;
    if (preferences == null) return const StudentData.empty();

    String? stored;
    try {
      stored = preferences.getString(storageKey);
    } catch (_) {
      return const StudentData.empty();
    }
    if (stored == null) {
      final demo = DemoRepository.data;
      await save(demo);
      return demo;
    }
    try {
      return _codec.decode(stored);
    } on FormatException {
      return const StudentData.empty();
    } on TypeError {
      return const StudentData.empty();
    }
  }

  @override
  Future<void> save(StudentData data) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      await preferences.setString(storageKey, _codec.encode(data));
    } catch (_) {
      // A temporarily unavailable platform store must not crash the app.
    }
  }
}
