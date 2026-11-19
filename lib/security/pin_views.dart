import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_lock.dart';
import 'pin_pad.dart';

/// Asks for the current PIN, with optional fingerprint, and calls [onVerified]
/// once either succeeds. Wrong guesses count toward [AppLock]'s lockout, and a
/// countdown is shown while one is running.
class PinVerifyView extends StatefulWidget {
  const PinVerifyView({
    super.key,
    required this.title,
    required this.onVerified,
    this.autoBiometric = false,
    this.allowForgot = false,
  });

  final String title;
  final VoidCallback onVerified;

  /// Open the fingerprint prompt as soon as the view appears.
  final bool autoBiometric;

  /// Show "Forgot PIN?", which resets the PIN after the phone's own screen
  /// lock is passed.
  final bool allowForgot;

  @override
  State<PinVerifyView> createState() => _PinVerifyViewState();
}

class _PinVerifyViewState extends State<PinVerifyView> {
  final _pad = GlobalKey<PinPadState>();
  final _lock = AppLock.instance;
  String? _message;
  bool _isError = false;
  bool _checking = false;
  bool _resetting = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startLockoutTicker();
    if (widget.autoBiometric && _lock.isBiometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _lockedOut => _lock.lockoutRemaining != null;

  void _startLockoutTicker() {
    _ticker?.cancel();
    if (!_lockedOut) return;
    _showLockout();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_lockedOut) {
        _showLockout();
      } else {
        t.cancel();
        setState(() {
          _message = 'Try again';
          _isError = false;
        });
      }
    });
  }

  void _showLockout() {
    final left = _lock.lockoutRemaining!;
    final m = left.inMinutes;
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    setState(() {
      _message = 'Too many wrong attempts.\nTry again in $m:$s';
      _isError = true;
    });
  }

  Future<void> _submit(String pin) async {
    setState(() => _checking = true);
    final result = await _lock.verifyPin(pin);
    if (!mounted) return;
    setState(() => _checking = false);
    switch (result) {
      case PinCheck.correct:
        widget.onVerified();
        break;
      case PinCheck.wrong:
        _pad.currentState?.reject();
        final left = AppLock.freeAttempts - _lock.failedAttempts;
        setState(() {
          _isError = true;
          _message = left <= 2
              ? 'Wrong PIN. $left attempt${left == 1 ? '' : 's'} before a lockout.'
              : 'Wrong PIN';
        });
        break;
      case PinCheck.lockedOut:
        _pad.currentState?.reject();
        _startLockoutTicker();
        break;
    }
  }

  Future<void> _biometric() async {
    final result = await _lock.unlockWithBiometrics();
    if (!mounted) return;
    switch (result) {
      case BiometricResult.success:
        widget.onVerified();
        break;
      case BiometricResult.lockedOut:
        setState(() {
          _isError = true;
          _message = 'Fingerprint is locked after too many tries. Use your PIN.';
        });
        break;
      case BiometricResult.unavailable:
        setState(() {
          _isError = false;
          _message = 'Fingerprint isn\'t available. Use your PIN.';
        });
        break;
      case BiometricResult.failed:
        break; // Cancelled; the keypad is right there.
    }
  }

  Future<void> _forgot() async {
    final result = await _lock.verifyDeviceOwner();
    if (!mounted) return;
    if (result == BiometricResult.success) {
      setState(() => _resetting = true);
    } else if (result == BiometricResult.unavailable) {
      setState(() {
        _isError = true;
        _message = 'Resetting needs a screen lock on this phone. '
            'Without one, the only way in is clearing the app\'s data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resetting) {
      return PinCreateView(
        title: 'Set a new PIN',
        onCreated: (pin) async {
          await _lock.resetPin(pin);
          widget.onVerified();
        },
      );
    }

    return PinPad(
      key: _pad,
      title: widget.title,
      message: _message,
      isError: _isError,
      enabled: !_checking && !_lockedOut,
      onCompleted: _submit,
      onBiometric: _lock.isBiometricEnabled ? _biometric : null,
      footer: widget.allowForgot
          ? TextButton(
              onPressed: _forgot,
              child: const Text(
                'Forgot PIN?',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            )
          : null,
    );
  }
}

/// Enter a new PIN, then enter it again to confirm.
class PinCreateView extends StatefulWidget {
  const PinCreateView({
    super.key,
    required this.onCreated,
    this.title = 'Create a PIN',
  });

  final String title;
  final ValueChanged<String> onCreated;

  @override
  State<PinCreateView> createState() => _PinCreateViewState();
}

class _PinCreateViewState extends State<PinCreateView> {
  final _pad = GlobalKey<PinPadState>();
  String? _first;
  String? _message;
  bool _isError = false;

  void _onCompleted(String pin) {
    if (_first == null) {
      if (_isWeak(pin)) {
        _pad.currentState?.reject();
        setState(() {
          _isError = true;
          _message = 'That PIN is easy to guess. Pick another.';
        });
        return;
      }
      _pad.currentState?.clear();
      setState(() {
        _first = pin;
        _isError = false;
        _message = null;
      });
    } else if (pin == _first) {
      widget.onCreated(pin);
    } else {
      _pad.currentState?.reject();
      setState(() {
        _first = null;
        _isError = true;
        _message = 'PINs didn\'t match. Start again.';
      });
    }
  }

  /// Rejects all-same digits and straight runs like 1234 or 9876.
  static bool _isWeak(String pin) {
    final d = pin.codeUnits;
    final step = d[1] - d[0];
    if (step.abs() > 1) return false;
    for (var i = 2; i < d.length; i++) {
      if (d[i] - d[i - 1] != step) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return PinPad(
      key: _pad,
      title: confirming ? 'Confirm your PIN' : widget.title,
      message: _message ??
          (confirming
              ? 'Enter the same ${AppLock.pinLength} digits again'
              : 'Choose ${AppLock.pinLength} digits. Don\'t reuse your M-Pesa PIN.'),
      isError: _isError,
      onCompleted: _onCompleted,
    );
  }
}

/* ------------------------- full-screen routes ------------------------- */

/// Pushes the create-and-confirm screen. Returns the new PIN, or null if the
/// user backed out.
Future<String?> showCreatePin(BuildContext context, {String title = 'Create a PIN'}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _PinRouteScaffold(
        child: PinCreateView(
          title: title,
          onCreated: (pin) => Navigator.of(context).pop(pin),
        ),
      ),
    ),
  );
}

/// Pushes the PIN check. Returns true once the PIN or fingerprint is accepted.
Future<bool> showVerifyPin(BuildContext context, {required String title}) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _PinRouteScaffold(
        child: PinVerifyView(
          title: title,
          onVerified: () => Navigator.of(context).pop(true),
        ),
      ),
    ),
  );
  return ok == true;
}

class _PinRouteScaffold extends StatelessWidget {
  const _PinRouteScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: AppBar(
        backgroundColor: AppColors.mainBackground,
        leading: const CloseButton(),
      ),
      body: child,
    );
  }
}
