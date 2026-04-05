import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database/database_helper.dart';
import '../models/transaction.dart';
import '../mpesa/mpesa_receiver.dart';
import '../theme/app_colors.dart';
import 'mpesa_parser.dart';

class NotificationEvent {
  final String? payload;
  NotificationEvent({this.payload});
}

class NotificationService {
  NotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static String? launchPayload;
  static final StreamController<NotificationEvent> _events =
      StreamController<NotificationEvent>.broadcast();
  static StreamSubscription<String>? _sub;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Track recently notified transactions to prevent duplicate notifications
  // Key: SMS payload hash, Value: timestamp when we last notified about it
  static final Map<String, int> _recentNotifications = {};

  static Stream<NotificationEvent> get stream => _events.stream;

  static Future<void> initialize() async {
    debugPrint('NotificationService: Initializing...');
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    debugPrint('NotificationService: Local notifications initialized');

    debugPrint('NotificationService: Setting up MpesaReceiver listener...');
    _sub?.cancel();
    _sub = MpesaReceiver.messages.listen(
      (payload) async {
        debugPrint('Received M-Pesa message: $payload');
      debugPrint('Received M-Pesa message: $payload');
      try {
        // Skip if we've processed this exact SMS recently (within 30 seconds)
        // This prevents duplicate notifications if the receiver sends the same SMS multiple times
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastNotified = _recentNotifications[payload];
        if (lastNotified != null && now - lastNotified < 30000) {
          // Skip duplicate SMS within 30 seconds
          debugPrint('Skipping duplicate SMS');
          return;
        }

        final result = MpesaParser.parse(payload);
        debugPrint('Parsed result: $result');
        if (result != null) {
          final transaction = result.transaction;
          final namedTransaction = Transaction(
            description: transaction.description,
            amount: transaction.amount,
            date: transaction.date,
            name: result.recipientName,
            rawMessage: result.rawMessage,
          );
          await DatabaseHelper.instance
              .insertUncategorizedTransaction(namedTransaction);

          final name = result.recipientName ?? 'New transaction';
          final amount = result.transaction.amount;
          
          // Record that we've notified about this SMS
          _recentNotifications[payload] = now;
          
          // Clean up old entries (older than 5 minutes) to prevent memory leak
          _recentNotifications.removeWhere(
            (key, timestamp) => now - timestamp > 300000,
          );
          
          await _showTransactionNotification(name, amount);
        }
      } catch (e) {
        // Prevent silent failures that could kill the subscription
        debugPrint('Error processing M-Pesa SMS: $e');
      }
    });
  }

  static Future<void> _showTransactionNotification(
      String name, double amount) async {
    const androidDetails = AndroidNotificationDetails(
      'uncategorized_transactions',
      'Uncategorized Transactions',
      channelDescription: 'Alerts for new uncategorized M-PESA transactions',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.mainBackground,
      styleInformation: DefaultStyleInformation(true, true),
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      0, // Use fixed ID to replace previous notification
      name,
      'Ksh ${amount.toStringAsFixed(0)} — tap to categorize',
      details,
      payload: 'categorize',
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == 'categorize') {
      _events.add(NotificationEvent(payload: 'categorize'));
    }
  }

  static Future<bool> isListenerEnabled() async {
    return MpesaReceiver.isListenerEnabled();
  }

  static Future<void> openListenerSettings() async {
    await MpesaReceiver.openListenerSettings();
  }
}
