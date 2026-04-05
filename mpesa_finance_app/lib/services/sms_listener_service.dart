import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mpesa_transaction.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'dart:async';

class SmsListenerService {
  static final SmsListenerService instance = SmsListenerService._();
  static const _channel = MethodChannel('com.example.mpesa_finance_app/sms');
  
  final _transactionController = StreamController<MpesaTransaction>.broadcast();
  Stream<MpesaTransaction> get transactionStream => _transactionController.stream;
  
  bool _isListening = false;

  SmsListenerService._() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final message = call.arguments['message'] as String?;
      if (message != null) {
        parseMpesaMessage(message);
      }
    }
  }

  Future<bool> requestPermissions() async {
    final smsStatus = await Permission.sms.status;
    if (smsStatus.isDenied) {
      final result = await Permission.sms.request();
      return result.isGranted;
    }
    return smsStatus.isGranted;
  }

  Future<bool> startListening() async {
    if (_isListening) return true;
    
    final hasPermission = await requestPermissions();
    if (!hasPermission) return false;

    try {
      final result = await _channel.invokeMethod('startSmsListener');
      _isListening = result == true;
      return _isListening;
    } on PlatformException {
      _setupFallbackListener();
      return true;
    }
  }

  void _setupFallbackListener() {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isListening) {
        timer.cancel();
        return;
      }
      await _checkForNewMessages();
    });
  }

  Future<void> _checkForNewMessages() async {
    try {
      final prefs = await _prefs;
      final pendingSms = prefs.getString('pending_sms');
      if (pendingSms != null && pendingSms.isNotEmpty) {
        final messages = pendingSms.split('|||new|||');
        for (final message in messages) {
          if (message.isNotEmpty) {
            parseMpesaMessage(message);
          }
        }
        await prefs.remove('pending_sms');
      }
    } catch (e) {
      // SharedPreferences not available
    }
  }

  static Future<dynamic> get _prefs async {
    final prefs = await SharedPreferences.getInstance();
    return prefs;
  }

  void parseMpesaMessage(String message) async {
    final transaction = _parseSmsToTransaction(message);
    if (transaction != null) {
      final id = await DatabaseHelper.instance.insertTransaction(transaction);
      final savedTransaction = transaction.copyWith(id: id);
      _transactionController.add(savedTransaction);
      await NotificationService.instance.showTransactionNotification(savedTransaction);
    }
  }

  MpesaTransaction? _parseSmsToTransaction(String message) {
    final lowerMessage = message.toLowerCase();
    
    if (!lowerMessage.contains('mpesa') && 
        !lowerMessage.contains('confirmation') &&
        !lowerMessage.contains('sent to') &&
        !lowerMessage.contains('received from')) {
      return null;
    }

    String type = 'unknown';
    double amount = 0.0;
    String phoneNumber = '';
    String? name;
    String? transactionId;

    // Sent money (Payment to)
    if (lowerMessage.contains('sent to') || lowerMessage.contains('payment to')) {
      type = 'sent';
      final amountMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)').firstMatch(message);
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
      
      final phoneMatch = RegExp(r'(\d{10,12})').firstMatch(message);
      if (phoneMatch != null) {
        phoneNumber = phoneMatch.group(1)!;
      }

      final nameMatch = RegExp(r'(?:sent to|payment to)\s+([A-Z]+(?:\s+[A-Z]+)?)\s+\d{10}', caseSensitive: false).firstMatch(message);
      if (nameMatch != null) {
        name = nameMatch.group(1);
      }
    }
    // Received money
    else if (lowerMessage.contains('received from') || lowerMessage.contains('you received')) {
      type = 'received';
      final amountMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)').firstMatch(message);
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
      
      final phoneMatch = RegExp(r'(\d{10,12})').firstMatch(message);
      if (phoneMatch != null) {
        phoneNumber = phoneMatch.group(1)!;
      }

      final nameMatch = RegExp(r'(?:received from|you received)\s+([A-Z]+(?:\s+[A-Z]+)?)\s+\d{10}', caseSensitive: false).firstMatch(message);
      if (nameMatch != null) {
        name = nameMatch.group(1);
      }
    }
    // Cashout
    else if (lowerMessage.contains('withdraw') || lowerMessage.contains('cashout')) {
      type = 'withdraw';
      final amountMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)').firstMatch(message);
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
    }
    // Airtime purchase
    else if (lowerMessage.contains('airtime') || lowerMessage.contains('top up')) {
      type = 'airtime';
      final amountMatch = RegExp(r'(\d+(?:,\d{3})*(?:\.\d+)?)').firstMatch(message);
      if (amountMatch != null) {
        amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
    }

    if (amount == 0) return null;

    final idMatch = RegExp(r'([A-Z0-9]{10,20})').firstMatch(message);
    if (idMatch != null) {
      transactionId = idMatch.group(1);
    }

    return MpesaTransaction(
      type: type,
      amount: amount,
      phoneNumber: phoneNumber,
      name: name,
      transactionId: transactionId,
      timestamp: DateTime.now(),
      message: message,
    );
  }

  void stopListening() {
    _isListening = false;
  }

  void dispose() {
    stopListening();
    _transactionController.close();
  }
}