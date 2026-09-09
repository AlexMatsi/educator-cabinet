import 'package:flutter/material.dart';

import 'app.dart';
import 'services/contact_action.dart';

void main() {
  runApp(EducatorCabinetApp(contactAction: SystemContactAction()));
}
