import 'dart:async';

import 'package:educator_cabinet/app.dart';
import 'package:educator_cabinet/data/demo_repository.dart';
import 'package:educator_cabinet/data/student_repository.dart';
import 'package:educator_cabinet/data/student_repository_factory.dart';
import 'package:educator_cabinet/models/student_data.dart';
import 'package:educator_cabinet/services/contact_action.dart';
import 'package:educator_cabinet/services/device_authenticator.dart';
import 'package:educator_cabinet/widgets/device_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDeviceAuthenticator implements DeviceAuthenticator {
  final responses = <Future<DeviceAuthenticationResult>>[];
  int calls = 0;

  void answer(DeviceAuthenticationStatus status, {String? message}) {
    responses.add(
      Future.value(DeviceAuthenticationResult(status, message: message)),
    );
  }

  void waitFor(Completer<DeviceAuthenticationResult> completer) {
    responses.add(completer.future);
  }

  @override
  Future<DeviceAuthenticationResult> authenticate() {
    calls++;
    return responses.removeAt(0);
  }
}

class CountingRepository implements StudentRepository {
  int loads = 0;

  @override
  Future<StudentData> load() async {
    loads++;
    return DemoRepository.data;
  }

  @override
  Future<void> save(StudentData data) async {}
}

class NoopContactAction implements ContactAction {
  @override
  Future<ContactActionResult> call(String phone) async =>
      ContactActionResult.openedDialer;
}

void main() {
  testWidgets('repository is loaded only once after successful unlock', (
    tester,
  ) async {
    final auth = FakeDeviceAuthenticator();
    final pending = Completer<DeviceAuthenticationResult>();
    auth.waitFor(pending);
    final repository = CountingRepository();
    var factoryCalls = 0;
    final lazyRepository = LazyStudentRepository(() async {
      factoryCalls++;
      return repository;
    });

    await tester.pumpWidget(
      EducatorCabinetApp(
        contactAction: NoopContactAction(),
        studentRepository: lazyRepository,
        requireDeviceAuthentication: true,
        deviceAuthenticator: auth,
      ),
    );
    await tester.pump();
    expect(factoryCalls, 0);
    expect(repository.loads, 0);
    expect(find.byKey(const Key('device-lock-screen')), findsOneWidget);

    pending.complete(
      const DeviceAuthenticationResult(DeviceAuthenticationStatus.success),
    );
    await tester.pumpAndSettle();
    expect(factoryCalls, 1);
    expect(repository.loads, 1);
    expect(find.text('Марія Весняна'), findsOneWidget);
    await tester.pump();
    expect(repository.loads, 1);
  });

  testWidgets('cancel keeps lock and retry can unlock', (tester) async {
    final auth = FakeDeviceAuthenticator()
      ..answer(DeviceAuthenticationStatus.canceled)
      ..answer(DeviceAuthenticationStatus.success);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceLockGate(
          authenticator: auth,
          childBuilder: (_) => const Text('Відкрито'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('скасовано'), findsOneWidget);
    expect(find.text('Відкрито'), findsNothing);

    await tester.tap(find.byKey(const Key('unlock-device')));
    await tester.pumpAndSettle();
    expect(find.text('Відкрито'), findsOneWidget);
    expect(auth.calls, 2);
  });

  testWidgets('unavailable authentication has a blocking explanation', (
    tester,
  ) async {
    final auth = FakeDeviceAuthenticator()
      ..answer(
        DeviceAuthenticationStatus.unavailable,
        message: 'Системне блокування не налаштовано.',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceLockGate(
          authenticator: auth,
          childBuilder: (_) => const Text('Секретні дані'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Системне блокування не налаштовано.'), findsOneWidget);
    expect(find.text('Секретні дані'), findsNothing);
  });

  testWidgets('privacy overlay hides content while inactive and paused', (
    tester,
  ) async {
    final auth = FakeDeviceAuthenticator()
      ..answer(DeviceAuthenticationStatus.success);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceLockGate(
          authenticator: auth,
          childBuilder: (_) => const Text('Приватний вміст'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final state in [AppLifecycleState.inactive, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      expect(find.byKey(const Key('privacy-overlay')), findsOneWidget);
      expect(find.text('Приватний вміст'), findsNothing);
    }
  });

  testWidgets('short background does not relock; 60 seconds does', (
    tester,
  ) async {
    var now = DateTime(2026);
    final auth = FakeDeviceAuthenticator()
      ..answer(DeviceAuthenticationStatus.success)
      ..answer(DeviceAuthenticationStatus.canceled);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceLockGate(
          authenticator: auth,
          clock: () => now,
          childBuilder: (_) => const Text('Відкрито'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 59));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Відкрито'), findsOneWidget);
    expect(auth.calls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 60));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-lock-screen')), findsOneWidget);
    expect(auth.calls, 2);
  });

  testWidgets('manual action locks mobile UI', (tester) async {
    final auth = FakeDeviceAuthenticator()
      ..answer(DeviceAuthenticationStatus.success);
    await tester.pumpWidget(
      EducatorCabinetApp(
        contactAction: NoopContactAction(),
        studentRepository: CountingRepository(),
        requireDeviceAuthentication: true,
        deviceAuthenticator: auth,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-lock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-lock-screen')), findsOneWidget);
  });

  testWidgets('lock screen fits a 390x844 display at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final auth = FakeDeviceAuthenticator()
      ..answer(DeviceAuthenticationStatus.canceled);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceLockGate(
          authenticator: auth,
          childBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Кабінет заблоковано'), findsOneWidget);
  });

  testWidgets('demo path never invokes authenticator', (tester) async {
    final auth = FakeDeviceAuthenticator();
    await tester.pumpWidget(
      EducatorCabinetApp(
        contactAction: NoopContactAction(),
        studentRepository: CountingRepository(),
        deviceAuthenticator: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(auth.calls, 0);
    expect(find.text('Марія Весняна'), findsOneWidget);
  });
}
