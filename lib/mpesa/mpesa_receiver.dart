import 'dart:async';
import 'package:flutter/services.dart';

class MpesaReceiver {
  static const EventChannel _channel = EventChannel('mpesa_events');
  static const MethodChannel _methodChannel = MethodChannel('mpesa_listener');

  static Stream<String> get messages =>
      _channel.receiveBroadcastStream().cast<String>();

  static Future<bool> isListenerEnabled() async {
    final enabled =
        await _methodChannel.invokeMethod<bool>('isListenerEnabled');
    return enabled ?? false;
  }

  static Future<void> openListenerSettings() async {
    await _methodChannel.invokeMethod('openListenerSettings');
  }

}
