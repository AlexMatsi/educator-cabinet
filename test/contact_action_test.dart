import 'package:educator_cabinet/services/contact_action.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens the exact number without copying it', () async {
    Uri? opened;
    var copied = false;
    final action = SystemContactAction(
      openDialer: (uri) async {
        opened = uri;
        return true;
      },
      copyNumber: (_) async {
        copied = true;
      },
    );
    expect(
      await action.call(' +380000000001 '),
      ContactActionResult.openedDialer,
    );
    expect(opened, Uri(scheme: 'tel', path: '+380000000001'));
    expect(copied, isFalse);
  });

  for (final throws in [false, true]) {
    test('copies the number when the dialer fails (throws: $throws)', () async {
      String? copied;
      final action = SystemContactAction(
        openDialer: (_) async {
          if (throws) throw PlatformException(code: 'unavailable');
          return false;
        },
        copyNumber: (number) async {
          copied = number;
        },
      );
      expect(await action.call('+380000000002'), ContactActionResult.copied);
      expect(copied, '+380000000002');
    });
  }

  test('reports clipboard failure without an unhandled exception', () async {
    final action = SystemContactAction(
      openDialer: (_) async => false,
      copyNumber: (_) async => throw PlatformException(code: 'denied'),
    );
    expect(await action.call('+380000000001'), ContactActionResult.unavailable);
  });

  test('empty number never invokes a system action', () async {
    var invoked = false;
    final action = SystemContactAction(
      openDialer: (_) async {
        invoked = true;
        return true;
      },
      copyNumber: (_) async {
        invoked = true;
      },
    );
    expect(await action.call('  '), ContactActionResult.unavailable);
    expect(invoked, isFalse);
  });
}
