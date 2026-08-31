import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'mpesa_background.dart';

class MpesaReceiver {
  static const EventChannel _channel = EventChannel('mpesa_events');
  static const MethodChannel _methodChannel = MethodChannel('mpesa_listener');

  static Stream<String>? _cachedStream;

  /// Emits whenever the native listener has queued something new. The payload is
  /// only a wake-up signal — always read the messages via [drainPending] so the
  /// foreground and background isolates cannot process the same message twice.
  static Stream<String> get wakeSignals {
    _cachedStream ??= _channel
        .receiveBroadcastStream()
        .transform<String>(
          StreamTransformer<Object?, String>.fromHandlers(
            handleData: (data, sink) => sink.add(data?.toString() ?? 'pending'),
            handleError: (error, stack, sink) {
              debugPrint('MpesaReceiver stream error: $error');
              // Invalidate the cache so the next access creates a fresh stream.
              _cachedStream = null;
              sink.addError(error, stack);
            },
          ),
        )
        .asBroadcastStream();
    return _cachedStream!;
  }

  /// Fetches every message the native listener has captured, without clearing
  /// them — call [acknowledgeProcessed] once each one is actually handled.
  /// Messages captured while the app was closed are included.
  static Future<List<String>> drainPending() async {
    try {
      final pending =
          await _methodChannel.invokeListMethod<Object?>('drainPending');
      return pending
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
    } catch (e) {
      debugPrint('MpesaReceiver drainPending error: $e');
      return const <String>[];
    }
  }

  /// Removes one message from the durable queue. Only call this once it has
  /// been fully handled (parsed and, if valid, written to the database) — if
  /// the process dies before this call, the message stays queued and is
  /// fetched again next time, instead of being lost.
  static Future<void> acknowledgeProcessed(String payload) async {
    try {
      await _methodChannel
          .invokeMethod('acknowledgeProcessed', {'payload': payload});
    } catch (e) {
      debugPrint('MpesaReceiver acknowledgeProcessed error: $e');
    }
  }

  /// Tells the native side which Dart entrypoint to run when a message arrives
  /// while the UI is closed. Must be called on every launch — callback handles
  /// are invalidated by a rebuild.
  static Future<void> registerBackgroundHandler() async {
    try {
      final handle = PluginUtilities.getCallbackHandle(mpesaBackgroundEntry);
      if (handle == null) {
        debugPrint('MpesaReceiver: could not resolve background entrypoint');
        return;
      }
      await _methodChannel.invokeMethod('registerBackgroundHandler', {
        'handle': handle.toRawHandle(),
      });
    } catch (e) {
      debugPrint('MpesaReceiver registerBackgroundHandler error: $e');
    }
  }

  /// Whether the OS has granted us READ_SMS, which is what lets the inbox sweep
  /// recover messages that arrived while the app had no process at all.
  static Future<bool> hasSmsPermission() async {
    try {
      final granted = await _methodChannel.invokeMethod<bool>('hasSmsPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('MpesaReceiver hasSmsPermission error: $e');
      return false;
    }
  }

  /// Sweeps the device SMS inbox and queues any M-Pesa message not already seen.
  ///
  /// This is the backstop for every gap the live listeners cannot cover: messages
  /// delivered while the process was dead, during a reboot, in a muted or
  /// currently-open conversation, or before the user granted any permission.
  ///
  /// The first sweep only looks at the past week, so enabling capture cannot
  /// dump years of old messages into the uncategorized queue.
  ///
  /// Returns how many new messages were queued.
  static Future<int> backfillFromSms() async {
    try {
      final queued = await _methodChannel.invokeMethod<int>('backfillSms');
      return queued ?? 0;
    } catch (e) {
      debugPrint('MpesaReceiver backfillFromSms error: $e');
      return 0;
    }
  }

  static Future<bool> isListenerEnabled() async {
    try {
      final enabled =
          await _methodChannel.invokeMethod<bool>('isListenerEnabled');
      return enabled ?? false;
    } catch (e) {
      debugPrint('MpesaReceiver isListenerEnabled error: $e');
      return false;
    }
  }

  static Future<void> openListenerSettings() async {
    try {
      await _methodChannel.invokeMethod('openListenerSettings');
    } catch (e) {
      debugPrint('MpesaReceiver openListenerSettings error: $e');
    }
  }

  /// Whether the OS is letting this app run unrestricted in the background.
  /// When false, Android (or an OEM battery manager) can kill the notification
  /// listener while the app is closed, silently stopping capture.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final ignoring = await _methodChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return ignoring ?? false;
    } catch (e) {
      debugPrint('MpesaReceiver isIgnoringBatteryOptimizations error: $e');
      return false;
    }
  }

  /// Opens the system dialog asking the user to exempt this app from battery
  /// optimization, so background capture survives being closed for a while.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _methodChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('MpesaReceiver requestIgnoreBatteryOptimizations error: $e');
    }
  }
}
