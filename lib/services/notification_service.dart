import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

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

  static final StreamController<NotificationEvent> _events =
      StreamController<NotificationEvent>.broadcast();
  static StreamSubscription<String>? _sub;

  /// Events raised before the UI subscribed (cold start from a notification tap,
  /// or a queue drained during startup). Broadcast streams drop those, so we
  /// hold the last one until the UI is ready to take it.
  static NotificationEvent? _pendingEvent;

  static void _emit(NotificationEvent event) {
    if (_events.hasListener) {
      _events.add(event);
    } else {
      _pendingEvent = event;
    }
  }

  /// Returns and clears any event that fired before the UI was listening.
  static NotificationEvent? takePendingEvent() {
    final event = _pendingEvent;
    _pendingEvent = null;
    return event;
  }

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Track recently processed transactions to prevent duplicate notifications
  // Key: hash of (amount + description), Value: timestamp when we last processed it
  static final Map<String, int> _recentNotifications = {};
  
  // Also track raw message hashes to catch exact duplicates
  static final Set<String> _recentMessageHashes = {};

  static Stream<NotificationEvent> get stream => _events.stream;

  static bool _localNotificationsReady = false;

  /// Local notifications only — safe to call from the headless background isolate,
  /// which has no navigator and no event stream consumers.
  static Future<void> initializeHeadless() async {
    if (_localNotificationsReady) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _localNotificationsReady = true;
  }

  static Future<void> initialize() async {
    debugPrint('NotificationService: Initializing...');
    await initializeHeadless();
    debugPrint('NotificationService: Local notifications initialized');

    // Tell the native listener which Dart entrypoint to run when a message
    // arrives while this UI is closed. Handles are invalidated by a rebuild, so
    // this has to happen on every launch.
    await MpesaReceiver.registerBackgroundHandler();

    debugPrint('NotificationService: Setting up MpesaReceiver listener...');
    _sub?.cancel();
    _sub = MpesaReceiver.wakeSignals.listen(
      (_) => drainAndProcess(),
      onError: (error, stacktrace) {
        debugPrint('Error in M-Pesa wake stream: $error\n$stacktrace');
        // Don't let stream errors stop us: the queue is on disk, so a later
        // drain still picks everything up.
        Future.delayed(const Duration(seconds: 1), drainAndProcess);
      },
      cancelOnError: false,
    );

    // Pick up anything captured while the app was closed.
    await drainAndProcess();

    // If the app was cold-started by tapping a transaction notification, the tap
    // is reported here rather than through _onNotificationTap.
    try {
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final payload = launch!.notificationResponse?.payload;
        debugPrint('NotificationService: launched by notification ($payload)');
        if (payload == 'categorize') {
          _emit(NotificationEvent(payload: 'categorize'));
        }
      }
    } catch (e) {
      debugPrint('NotificationService launch details error: $e');
    }
  }

  /// Called when the app comes back to the foreground: drain anything the native
  /// listener captured, then let the UI offer to categorise whatever is waiting
  /// (it may have been stored by the background isolate, in another isolate's
  /// event stream that this one never saw).
  static Future<void> onResumed() async {
    await drainAndProcess();
    _emit(NotificationEvent(payload: 'categorize'));
  }

  /// Takes every message the native listener has queued and processes it.
  /// Called on launch, on resume, and whenever the native side signals.
  static Future<void> drainAndProcess() async {
    final pending = await MpesaReceiver.drainPending();
    if (pending.isEmpty) return;
    debugPrint('NotificationService: draining ${pending.length} queued message(s)');
    for (final payload in pending) {
      await _processPayload(payload);
    }
  }

  static Future<void> _processPayload(String payload) async {
    debugPrint('Received M-Pesa message: $payload');
    try {
      // First, check for exact duplicate messages using payload hash
      // This catches the same SMS being delivered multiple times rapidly
      final payloadHash = md5.convert(utf8.encode(payload)).toString();
      final now = DateTime.now().millisecondsSinceEpoch;

      if (_recentMessageHashes.contains(payloadHash)) {
        debugPrint('Skipping exact duplicate message (already seen within current session)');
        return;
      }

      // Add to recent hashes for this session
      _recentMessageHashes.add(payloadHash);

      final result = MpesaParser.parse(payload);
      debugPrint('Parsed result: $result');
      if (result == null) return;

      try {
        final transaction = result.transaction;

        // Create a unique key based on amount and description
        // This prevents duplicate processing even if message format varies slightly
        final transactionKey = '${transaction.amount}_${transaction.description}';
        final txnHash = md5.convert(utf8.encode(transactionKey)).toString();

        // Check if we've already processed this transaction recently (within 2 minutes)
        // to prevent processing the same transaction multiple times
        final lastProcessed = _recentNotifications[txnHash];
        if (lastProcessed != null && now - lastProcessed < 120000) {
          debugPrint('Skipping duplicate transaction (processed within last 2 minutes): $transactionKey');
          return;
        }

        // Record that we've processed this transaction
        _recentNotifications[txnHash] = now;

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

        // Clean up old entries (older than 5 minutes) to prevent memory leak
        _recentNotifications.removeWhere(
          (key, timestamp) => now - timestamp > 300000,
        );

        // Also periodically clean up message hashes to prevent unbounded memory growth
        if (_recentMessageHashes.length > 100) {
          _recentMessageHashes.clear();
        }

        await _showTransactionNotification(name, amount);
        _emit(NotificationEvent(payload: 'categorize'));
      } catch (dbError) {
        debugPrint('Error processing parsed transaction: $dbError');
      }
    } catch (e) {
      // Prevent silent failures that could kill the subscription
      debugPrint('Error processing M-Pesa SMS: $e\nStack trace: ${StackTrace.current}');
    }
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
