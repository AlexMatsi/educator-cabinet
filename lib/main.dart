import 'package:flutter/material.dart';

import 'app.dart';
import 'data/shared_preferences_student_repository.dart';
import 'services/contact_action.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final studentRepository = await SharedPreferencesStudentRepository.create();
  runApp(
    EducatorCabinetApp(
      contactAction: SystemContactAction(),
      studentRepository: studentRepository,
    ),
  );
}
