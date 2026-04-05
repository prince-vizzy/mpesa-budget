import 'package:flutter/foundation.dart';
import '../models/transaction.dart';

class MpesaParseResult {
  final Transaction transaction;
  final String? recipientName;
  final String rawMessage;

  MpesaParseResult({required this.transaction, this.recipientName, required this.rawMessage});
}

class MpesaParser {
  static MpesaParseResult? parse(String text) {
    try {
      debugPrint('Parsing M-Pesa text: $text');
      final normalized = text.toLowerCase();
      final looksMpesa = normalized.contains('m-pesa') ||
          normalized.contains('mpesa') ||
          normalized.contains('ksh');
      if (!looksMpesa) {
        debugPrint('Not an M-Pesa message');
        return null;
      }

      // Keep expense-like events only to fit budget tracking.
      final expenseLike = normalized.contains('sent') ||
          normalized.contains('paid') ||
          normalized.contains('buy') ||
          normalized.contains('withdraw') ||
          normalized.contains('airtime');
      if (!expenseLike) {
        debugPrint('Not an expense-like event');
        return null;
      }

      final amountMatch =
          RegExp(r'Ksh([\d,]+\.?\d*)').firstMatch(text);

      if (amountMatch == null) {
        debugPrint('No amount found');
        return null;
      }

      final amount = double.parse(
        amountMatch.group(1)!.replaceAll(',', ''),
      );

      String? recipientName;

      // "sent to NAME" or "paid to NAME" - get first name only (first word)
      final sentMatch =
          RegExp(r'(?:sent|paid)\s+to\s+([A-Z]+)', caseSensitive: false)
              .firstMatch(text);
      if (sentMatch != null) {
        recipientName = sentMatch.group(1)!.trim();
        debugPrint('Found recipient name (sent): $recipientName');
      }

      // "withdrawn from NAME" or "buy goods to NAME"
      if (recipientName == null) {
        final otherMatch =
            RegExp(r'(?:withdrawn\s+from|goods\s+to)\s+([A-Z]+)', caseSensitive: false)
                .firstMatch(text);
        if (otherMatch != null) {
          recipientName = otherMatch.group(1)!.trim();
          debugPrint('Found recipient name (other): $recipientName');
        }
      }

      return MpesaParseResult(
        transaction: Transaction(
          description: text.split('.').first.trim(),
          amount: amount,
          date: DateTime.now(),
          name: recipientName,
          rawMessage: text,
        ),
        recipientName: recipientName,
        rawMessage: text,
      );
    } catch (e) {
      debugPrint('Parse error: $e');
      return null;
    }
  }

  static String? extractName(String text) {
    final result = parse(text);
    return result?.recipientName;
  }

  static double? extractAmount(String text) {
    final result = parse(text);
    return result?.transaction.amount;
  }
}