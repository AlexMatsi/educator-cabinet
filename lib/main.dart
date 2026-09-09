import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/student_repository_factory.dart';
import 'services/contact_action.dart';
import 'services/device_authenticator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  final studentRepository = isMobile
      ? LazyStudentRepository(createStudentRepository)
      : await createStudentRepository();
  runApp(
    EducatorCabinetApp(
      contactAction: SystemContactAction(),
      studentRepository: studentRepository,
      requireDeviceAuthentication: isMobile,
      deviceAuthenticator: isMobile ? LocalDeviceAuthenticator() : null,
    ),
  );
}
