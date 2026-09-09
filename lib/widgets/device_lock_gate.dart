import 'package:flutter/material.dart';

import '../services/device_authenticator.dart';

typedef Clock = DateTime Function();

class DeviceLockGate extends StatefulWidget {
  const DeviceLockGate({
    required this.authenticator,
    required this.childBuilder,
    this.relockAfter = const Duration(seconds: 60),
    this.clock = DateTime.now,
    super.key,
  });

  final DeviceAuthenticator authenticator;
  final Widget Function(VoidCallback lock) childBuilder;
  final Duration relockAfter;
  final Clock clock;

  @override
  State<DeviceLockGate> createState() => DeviceLockGateState();
}

class DeviceLockGateState extends State<DeviceLockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;
  bool _privacyHidden = false;
  String? _message;
  DateTime? _backgroundedAt;
  bool _backgroundedForAuthentication = false;
  Widget? _unlockedChild;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= widget.clock();
      _backgroundedForAuthentication =
          _backgroundedForAuthentication || _authenticating;
      if (!_privacyHidden && mounted) setState(() => _privacyHidden = true);
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    final timedOut =
        !_backgroundedForAuthentication &&
        backgroundedAt != null &&
        widget.clock().difference(backgroundedAt) >= widget.relockAfter;
    _backgroundedForAuthentication = false;
    if (timedOut && !_authenticating) {
      lock();
      _authenticate();
    } else if (mounted) {
      setState(() => _privacyHidden = false);
    }
  }

  void lock() {
    if (!mounted) return;
    setState(() {
      _unlocked = false;
      _privacyHidden = false;
      _message = null;
      _unlockedChild = null;
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating || _unlocked) return;
    setState(() {
      _authenticating = true;
      _message = null;
    });
    final result = await widget.authenticator.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      _privacyHidden =
          lifecycleState != null && lifecycleState != AppLifecycleState.resumed;
      if (result.status == DeviceAuthenticationStatus.success) {
        _unlocked = true;
        _unlockedChild ??= widget.childBuilder(lock);
      } else {
        _message =
            result.message ??
            'Автентифікацію скасовано. Дані залишаються заблокованими.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_privacyHidden) {
      return const ColoredBox(
        key: Key('privacy-overlay'),
        color: Color(0xff18211f),
        child: Center(child: Icon(Icons.lock, color: Colors.white, size: 48)),
      );
    }
    if (_unlocked) return _unlockedChild!;
    return Scaffold(
      key: const Key('device-lock-screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Кабінет заблоковано',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message ??
                        'Підтвердьте особу системним способом пристрою, щоб відкрити локальні дані.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('unlock-device'),
                    onPressed: _authenticating ? null : _authenticate,
                    icon: _authenticating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open),
                    label: Text(
                      _authenticating ? 'Перевірка…' : 'Спробувати ще раз',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
