import 'package:flutter/material.dart';

import 'app.dart';
import 'data/student_repository_factory.dart';
import 'services/contact_action.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final studentRepository = await createStudentRepository();
  runApp(
    EducatorCabinetApp(
      contactAction: SystemContactAction(),
      studentRepository: studentRepository,
    ),
  );
}
