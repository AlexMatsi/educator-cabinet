import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum ContactActionResult { openedDialer, copied, unavailable }

abstract interface class ContactAction {
  Future<ContactActionResult> call(String phone);
}

class SystemContactAction implements ContactAction {
  @override
  Future<ContactActionResult> call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri) && await launchUrl(uri)) {
      return ContactActionResult.openedDialer;
    }
    await Clipboard.setData(ClipboardData(text: phone));
    return ContactActionResult.copied;
  }
}
