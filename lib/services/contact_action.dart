import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum ContactActionResult { openedDialer, copied, unavailable }

String contactActionMessage(ContactActionResult result) =>
    result == ContactActionResult.copied
    ? 'Телефонний застосунок недоступний. Номер скопійовано.'
    : 'Не вдалося відкрити набір або скопіювати номер. Номер доступний у картці.';

abstract interface class ContactAction {
  Future<ContactActionResult> call(String phone);
}

class SystemContactAction implements ContactAction {
  SystemContactAction({
    Future<bool> Function(Uri)? openDialer,
    Future<void> Function(String)? copyNumber,
  }) : _openDialer = openDialer ?? _launch,
       _copyNumber = copyNumber ?? _copy;

  final Future<bool> Function(Uri) _openDialer;
  final Future<void> Function(String) _copyNumber;

  static Future<bool> _launch(Uri uri) => launchUrl(uri);
  static Future<void> _copy(String phone) =>
      Clipboard.setData(ClipboardData(text: phone));

  @override
  Future<ContactActionResult> call(String phone) async {
    final number = phone.trim();
    if (number.isEmpty) return ContactActionResult.unavailable;
    try {
      // Try the action directly: capability queries can return false even
      // when a dialer is available, depending on platform visibility rules.
      if (await _openDialer(Uri(scheme: 'tel', path: number))) {
        return ContactActionResult.openedDialer;
      }
    } catch (_) {
      // The plugin or operating system may reject the action.
    }
    try {
      await _copyNumber(number);
      return ContactActionResult.copied;
    } catch (_) {
      return ContactActionResult.unavailable;
    }
  }
}
