import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum DeviceAuthenticationStatus { success, canceled, unavailable, error }

class DeviceAuthenticationResult {
  const DeviceAuthenticationResult(this.status, {this.message});

  final DeviceAuthenticationStatus status;
  final String? message;
}

abstract interface class DeviceAuthenticator {
  Future<DeviceAuthenticationResult> authenticate();
}

class LocalDeviceAuthenticator implements DeviceAuthenticator {
  LocalDeviceAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<DeviceAuthenticationResult> authenticate() async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) {
        return const DeviceAuthenticationResult(
          DeviceAuthenticationStatus.unavailable,
          message:
              'На пристрої не налаштовано системний спосіб розблокування. '
              'Налаштуйте код-пароль, Face ID, Touch ID або відбиток у системних налаштуваннях.',
        );
      }
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Розблокуйте кабінет вихователя',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return DeviceAuthenticationResult(
        authenticated
            ? DeviceAuthenticationStatus.success
            : DeviceAuthenticationStatus.canceled,
      );
    } on PlatformException {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.error,
        message:
            'Системна автентифікація зараз недоступна або тимчасово заблокована. '
            'Перевірте налаштування пристрою та спробуйте ще раз.',
      );
    } on Object {
      return const DeviceAuthenticationResult(
        DeviceAuthenticationStatus.error,
        message:
            'Не вдалося виконати системну автентифікацію. Спробуйте ще раз.',
      );
    }
  }
}
