import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../database/database_helper.dart';

enum PinCheck { correct, wrong, lockedOut }

enum BiometricResult { success, failed, unavailable, lockedOut }

/// App lock state: whether a PIN is set, whether fingerprint unlock is on, and
/// whether the app is locked right now.
///
/// The PIN is never stored. Only a salted, iterated HMAC-SHA256 of it is kept
/// in `user_settings`. A short PIN has few possible values, so the hash alone
/// would not stop a determined attacker with the database file. The real
/// protection is the escalating lockout after wrong guesses, which is also
/// persisted so restarting the app does not reset it.
class AppLock extends ChangeNotifier {
  AppLock._();
  static final AppLock instance = AppLock._();

  static const int pinLength = 4;

  /// Wrong guesses allowed before the first lockout.
  static const int freeAttempts = 5;
  static const Duration _firstLockout = Duration(seconds: 30);
  static const Duration _maxLockout = Duration(hours: 1);
  static const int _hashRounds = 10000;

  static const _kEnabled = 'app_lock_enabled';
  static const _kBiometric = 'app_lock_biometric';
  static const _kHash = 'app_lock_pin_hash';
  static const _kSalt = 'app_lock_pin_salt';
  static const _kFailed = 'app_lock_failed_attempts';
  static const _kLockedUntil = 'app_lock_locked_until';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _loaded = false;
  bool _enabled = false;
  bool _biometricEnabled = false;
  bool _locked = false;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  bool _authenticating = false;

  bool get isLoaded => _loaded;
  bool get isEnabled => _enabled;
  bool get isBiometricEnabled => _enabled && _biometricEnabled;
  bool get isLocked => _enabled && _locked;
  int get failedAttempts => _failedAttempts;

  /// How long until another PIN guess is accepted, or null if one is now.
  Duration? get lockoutRemaining {
    final until = _lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  Future<void> load() async {
    final db = DatabaseHelper.instance;
    _enabled = await db.getUserSetting(_kEnabled) == 'true' &&
        (await db.getUserSetting(_kHash) ?? '').isNotEmpty;
    _biometricEnabled = await db.getUserSetting(_kBiometric) == 'true';
    _failedAttempts = int.tryParse(await db.getUserSetting(_kFailed) ?? '') ?? 0;
    final until = int.tryParse(await db.getUserSetting(_kLockedUntil) ?? '');
    _lockedUntil =
        until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);
    // A cold start always begins locked.
    _locked = _enabled;
    _loaded = true;
    notifyListeners();
  }

  /* ------------------------- lifecycle ------------------------- */

  /// Called when the app leaves the screen. The system biometric prompt only
  /// pauses the activity rather than stopping it, but the guard covers devices
  /// that report it differently, so authenticating never re-locks the app.
  void onBackgrounded() {
    if (!_enabled || _authenticating || _locked) return;
    _locked = true;
    notifyListeners();
  }

  void _unlock() {
    _locked = false;
    notifyListeners();
  }

  /* ---------------------------- PIN ---------------------------- */

  /// Turns the lock on with [pin]. The app stays unlocked for this session.
  Future<void> enable(String pin) async {
    await _storePin(pin);
    await DatabaseHelper.instance.setUserSetting(_kEnabled, 'true');
    _enabled = true;
    _locked = false;
    notifyListeners();
  }

  Future<void> disable() async {
    final db = DatabaseHelper.instance;
    for (final key in [_kEnabled, _kBiometric, _kHash, _kSalt]) {
      await db.setUserSetting(key, '');
    }
    await _setFailures(0, null);
    _enabled = false;
    _biometricEnabled = false;
    _locked = false;
    notifyListeners();
  }

  Future<void> changePin(String pin) => _storePin(pin);

  /// Used after "Forgot PIN?" has been passed with the phone's screen lock.
  Future<void> resetPin(String pin) async {
    await _storePin(pin);
    _unlock();
  }

  /// Checks [pin], counting wrong guesses and applying the lockout. A correct
  /// PIN also unlocks the app.
  Future<PinCheck> verifyPin(String pin) async {
    if (lockoutRemaining != null) return PinCheck.lockedOut;

    final db = DatabaseHelper.instance;
    final storedHash = await db.getUserSetting(_kHash) ?? '';
    final salt = await db.getUserSetting(_kSalt) ?? '';
    if (storedHash.isEmpty || salt.isEmpty) return PinCheck.wrong;

    final hash = await compute(_hashPin, [pin, salt]);
    if (_constantTimeEquals(hash, storedHash)) {
      await _setFailures(0, null);
      _unlock();
      return PinCheck.correct;
    }

    final failed = _failedAttempts + 1;
    DateTime? until;
    if (failed >= freeAttempts) {
      // 30s, 1m, 2m, 4m, ... capped at an hour.
      final doublings = min(failed - freeAttempts, 10);
      var wait = _firstLockout * (1 << doublings);
      if (wait > _maxLockout) wait = _maxLockout;
      until = DateTime.now().add(wait);
    }
    await _setFailures(failed, until);
    notifyListeners();
    return until == null ? PinCheck.wrong : PinCheck.lockedOut;
  }

  Future<void> _storePin(String pin) async {
    final rng = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rng.nextInt(256)));
    final hash = await compute(_hashPin, [pin, salt]);
    final db = DatabaseHelper.instance;
    await db.setUserSetting(_kSalt, salt);
    await db.setUserSetting(_kHash, hash);
    await _setFailures(0, null);
  }

  Future<void> _setFailures(int count, DateTime? until) async {
    _failedAttempts = count;
    _lockedUntil = until;
    final db = DatabaseHelper.instance;
    await db.setUserSetting(_kFailed, '$count');
    await db.setUserSetting(
        _kLockedUntil, until == null ? '' : '${until.millisecondsSinceEpoch}');
  }

  /* ------------------------- biometrics ------------------------- */

  /// True when the phone has a fingerprint (or face) enrolled.
  Future<bool> biometricsAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Turning fingerprint unlock on asks for the fingerprint once, so it cannot
  /// be switched on by someone who only has the PIN.
  Future<BiometricResult> setBiometricEnabled(bool value) async {
    if (value) {
      final result = await _biometric('Confirm your fingerprint to use it to unlock');
      if (result != BiometricResult.success) return result;
    }
    await DatabaseHelper.instance.setUserSetting(_kBiometric, '$value');
    _biometricEnabled = value;
    notifyListeners();
    return BiometricResult.success;
  }

  Future<BiometricResult> unlockWithBiometrics() async {
    if (!isBiometricEnabled) return BiometricResult.unavailable;
    final result = await _biometric('Unlock your budget');
    if (result == BiometricResult.success) {
      await _setFailures(0, null);
      _unlock();
    }
    return result;
  }

  /// "Forgot PIN": the phone's own screen lock (PIN, pattern, password or
  /// fingerprint) proves the owner is holding it, after which a new PIN can be
  /// set. Without a phone screen lock there is no way back in short of clearing
  /// the app's data.
  Future<BiometricResult> verifyDeviceOwner() =>
      _authenticateRaw('Verify it\'s you to reset your app PIN', biometricOnly: false);

  Future<BiometricResult> _biometric(String reason) =>
      _authenticateRaw(reason, biometricOnly: true);

  Future<BiometricResult> _authenticateRaw(String reason,
      {required bool biometricOnly}) async {
    if (_authenticating) return BiometricResult.failed;
    _authenticating = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricResult.success : BiometricResult.failed;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return BiometricResult.lockedOut;
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          return BiometricResult.unavailable;
        default:
          return BiometricResult.failed;
      }
    } catch (_) {
      return BiometricResult.failed;
    } finally {
      _authenticating = false;
    }
  }
}

/// Runs in an isolate: ten thousand HMAC rounds would stall the keypad's
/// animation on a slow phone.
String _hashPin(List<String> args) {
  final pin = utf8.encode(args[0]);
  final hmac = Hmac(sha256, base64Decode(args[1]));
  var digest = hmac.convert(pin).bytes;
  for (var i = 1; i < AppLock._hashRounds; i++) {
    digest = hmac.convert([...digest, ...pin]).bytes;
  }
  return base64Encode(digest);
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
