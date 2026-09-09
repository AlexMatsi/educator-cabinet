import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/shared_preferences_student_repository.dart';
import 'package:educator_cabinet/data/student_data_codec.dart';
import 'package:educator_cabinet/models/student_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferencesStudentRepository> repositoryWith(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferencesStudentRepository(
      preferences: await SharedPreferences.getInstance(),
    );
  }

  test('saved data is read back unchanged', () async {
    final repository = await repositoryWith({});
    await repository.save(DemoRepository.data);

    final loaded = await repository.load();

    expect(
      const StudentDataCodec().encode(loaded),
      const StudentDataCodec().encode(DemoRepository.data),
    );
  });

  test('an absolutely empty store is seeded once', () async {
    final repository = await repositoryWith({});

    final loaded = await repository.load();

    expect(loaded.students, hasLength(6));
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        SharedPreferencesStudentRepository.storageKey,
      ),
      isTrue,
    );
  });

  test('saved empty data is not seeded on a later load', () async {
    final repository = await repositoryWith({});
    await repository.save(const StudentData.empty());

    final loaded = await repository.load();

    expect(loaded.students, isEmpty);
    expect(loaded.classes, isEmpty);
  });

  test('damaged JSON safely returns empty data without reseeding', () async {
    final repository = await repositoryWith({
      SharedPreferencesStudentRepository.storageKey: '{damaged',
    });

    final loaded = await repository.load();

    expect(loaded.students, isEmpty);
    expect(loaded.classes, isEmpty);
  });

  test('unknown schema safely returns empty data', () async {
    final repository = await repositoryWith({
      SharedPreferencesStudentRepository.storageKey:
          '{"schemaVersion":999,"classes":[],"students":[]}',
    });

    expect((await repository.load()).students, isEmpty);
  });

  test('unavailable storage safely returns empty data', () async {
    final repository = SharedPreferencesStudentRepository(preferences: null);

    await repository.save(DemoRepository.data);
    final loaded = await repository.load();

    expect(loaded.students, isEmpty);
  });
}
