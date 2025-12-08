import 'dart:async';
import 'package:flutter/services.dart';

class MpesaReceiver {
  static const EventChannel _channel = EventChannel('mpesa_events');

  static Stream<String> get messages =>
      _channel.receiveBroadcastStream().cast<String>();
}
