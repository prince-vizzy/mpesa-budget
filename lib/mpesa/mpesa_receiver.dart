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

  /// Atomically takes every message the native listener has captured. Messages
  /// captured while the app was closed are included.
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
}
