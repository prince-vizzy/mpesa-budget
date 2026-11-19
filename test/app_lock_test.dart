import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mpesa_tracker/database/database_helper.dart';
import 'package:mpesa_tracker/security/app_lock.dart';

/// Covers the PIN side of the app lock: storage, checking, the lockout after
/// wrong guesses, and that none of it resets on restart.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final lock = AppLock.instance;

  setUp(() async {
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
    await DatabaseHelper.resetForTesting(inMemoryDatabasePath);
    await lock.load();
  });

  test('starts off with no lock', () {
    expect(lock.isEnabled, isFalse);
    expect(lock.isLocked, isFalse);
  });

  test('the PIN itself is never stored', () async {
    await lock.enable('2580');
    final db = DatabaseHelper.instance;
    final hash = await db.getUserSetting('app_lock_pin_hash');
    expect(hash, isNotEmpty);
    expect(hash, isNot(contains('2580')));
  });

  test('enabling keeps the current session open, a restart locks it', () async {
    await lock.enable('2580');
    expect(lock.isLocked, isFalse);

    await lock.load(); // what happens on a cold start
    expect(lock.isEnabled, isTrue);
    expect(lock.isLocked, isTrue);
  });

  test('going to the background locks, the right PIN unlocks', () async {
    await lock.enable('2580');
    lock.onBackgrounded();
    expect(lock.isLocked, isTrue);

    expect(await lock.verifyPin('1111'), PinCheck.wrong);
    expect(lock.isLocked, isTrue);

    expect(await lock.verifyPin('2580'), PinCheck.correct);
    expect(lock.isLocked, isFalse);
    expect(lock.failedAttempts, 0);
  });

  test('locks out after five wrong guesses, and a restart does not clear it',
      () async {
    await lock.enable('2580');
    for (var i = 1; i < AppLock.freeAttempts; i++) {
      expect(await lock.verifyPin('0000'), PinCheck.wrong);
    }
    expect(await lock.verifyPin('0000'), PinCheck.lockedOut);
    expect(lock.lockoutRemaining, isNotNull);

    // Even the right PIN is refused during the lockout.
    expect(await lock.verifyPin('2580'), PinCheck.lockedOut);

    await lock.load();
    expect(lock.lockoutRemaining, isNotNull);
    expect(lock.failedAttempts, AppLock.freeAttempts);
  });

  test('changing the PIN retires the old one', () async {
    await lock.enable('2580');
    await lock.changePin('7319');
    lock.onBackgrounded();
    expect(await lock.verifyPin('2580'), PinCheck.wrong);
    expect(await lock.verifyPin('7319'), PinCheck.correct);
  });

  test('disabling clears the PIN and survives a restart', () async {
    await lock.enable('2580');
    await lock.disable();
    await lock.load();
    expect(lock.isEnabled, isFalse);
    expect(lock.isLocked, isFalse);
    expect(await DatabaseHelper.instance.getUserSetting('app_lock_pin_hash'), '');
  });
}
