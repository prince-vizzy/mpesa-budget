import 'dart:async';
import 'package:flutter/services.dart';

class MpesaReceiver {
  static const EventChannel _channel = EventChannel('mpesa_events');
  static const MethodChannel _methodChannel = MethodChannel('mpesa_listener');

  static Stream<String> get messages {
    try {
      return _channel.receiveBroadcastStream().transform(
        StreamTransformer.fromHandlers(
          handleData: (data, sink) {
            if (data is String) {
              sink.add(data);
            } else if (data != null) {
              sink.add(data.toString());
            }
          },
          handleError: (error, stack, sink) {
            print('MpesaReceiver stream error: $error');
          },
        ),
      );
    } catch (e) {
      print('MpesaReceiver error: $e');
      return const Stream.empty();
    }
  }

  static Future<bool> isListenerEnabled() async {
    try {
      final enabled =
          await _methodChannel.invokeMethod<bool>('isListenerEnabled');
      return enabled ?? false;
    } catch (e) {
      print('MpesaReceiver isListenerEnabled error: $e');
      return false;
    }
  }

  static Future<void> openListenerSettings() async {
    try {
      await _methodChannel.invokeMethod('openListenerSettings');
    } catch (e) {
      print('MpesaReceiver openListenerSettings error: $e');
    }
  }

}
