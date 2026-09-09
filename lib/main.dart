import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local_key_value_store.dart';
import 'data/student_repository.dart';
import 'services/contact_action.dart';

void main() {
  runApp(
    EducatorCabinetApp(
      contactAction: SystemContactAction(),
      repository: LocalStudentRepository(const SharedPreferencesStore()),
    ),
  );
}
