import 'dart:async';
import 'package:flutter/services.dart';

class MpesaNotificationService {
  static const _channel = EventChannel('mpesa_notifications');

  static Stream<String> get messages =>
      _channel.receiveBroadcastStream().cast<String>();
}
