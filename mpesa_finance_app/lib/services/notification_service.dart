import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../models/mpesa_transaction.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const String _channelId = 'mpesa_transactions';
  static const String _channelName = 'M-Pesa Transactions';
  static const String _channelDescription = 'Notifications for new M-Pesa transactions';

  Function(int transactionId)? onCategorySelected;
  int? _lastTransactionId;

  NotificationService._();

  static NotificationService get instance => _instance;

  int? get lastTransactionId => _lastTransactionId;
  
  void clearLastTransactionId() => _lastTransactionId = null;

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final parts = payload.split(':');
      if (parts.isNotEmpty) {
        final transactionId = int.tryParse(parts[0]);
        _lastTransactionId = transactionId;
        if (transactionId != null && onCategorySelected != null) {
          onCategorySelected!(transactionId);
        }
      }
    }
  }

  Future<void> showTransactionNotification(MpesaTransaction transaction) async {
    _lastTransactionId = transaction.id;
    
    final amountStr = transaction.amount.toStringAsFixed(0);
    final title = transaction.type == 'received' 
        ? 'Money Received' 
        : 'Money Sent';
    final body = transaction.name != null 
        ? 'KES $amountStr to ${transaction.name}'
        : 'KES $amountStr ${transaction.type}';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'New M-Pesa Transaction',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction('food', 'Food', showsUserInterface: true),
        const AndroidNotificationAction('transport', 'Transport', showsUserInterface: true),
        const AndroidNotificationAction('bills', 'Bills', showsUserInterface: true),
        const AndroidNotificationAction('shopping', 'Shopping', showsUserInterface: true),
        const AndroidNotificationAction('other', 'Other', showsUserInterface: true),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      transaction.id ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      details,
      payload: '${transaction.id}:${transaction.type}',
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}