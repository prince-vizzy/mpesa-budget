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
          normalized.contains('ksh') ||
          normalized.contains('kes');
      if (!looksMpesa) {
        debugPrint('Not an M-Pesa message');
        return null;
      }

      // Keep expense-like events only to fit budget tracking.
      final expenseLike = normalized.contains('sent') ||
          normalized.contains('paid') ||
          normalized.contains('buy') ||
          normalized.contains('withdraw') ||
          normalized.contains('airtime') ||
          normalized.contains('transfer');
      if (!expenseLike) {
        debugPrint('Not an expense-like event');
        return null;
      }

  // Robust amount extraction - handle optional space after KES/Ksh
  final amountMatch =
      RegExp(r'(?:Ksh|KES)\s*?([\d,]+\.?\d*)', caseSensitive: false).firstMatch(text);

  if (amountMatch == null) {
    debugPrint('No amount found in: $text');
    return null;
  }

  final amountStr = amountMatch.group(1)!.replaceAll(',', '');
  final amount = double.tryParse(amountStr) ?? 0.0;
  if (amount == 0) {
    debugPrint('Invalid amount parsed: $amountStr');
    return null;
  }

  String? recipientName, phoneNumber;
  debugPrint('Amount found: KES $amount from "$amountStr"');

  // Bank to M-PESA transfer pattern: "to PHONE - NAME" (keep original + new)
  final bankTransferMatch =
      RegExp(r'to\s+(\d{9,12})\s*-\s*([A-Z][^.!]+)', caseSensitive: false).firstMatch(text);
  if (bankTransferMatch != null) {
    phoneNumber = bankTransferMatch.group(1);
    recipientName = bankTransferMatch.group(2)!.trim();
    // Trim trailing punctuation and "successfully processed", then first name only
    recipientName = recipientName.replaceAll(RegExp(r'\s*(?:successfully|processed|confirmed).*', caseSensitive: false), '').trim();
    if (recipientName!.contains(' ')) {
      recipientName = recipientName.split(' ')[0];
    }
    debugPrint('Cleaned bank name to first: "$recipientName"');
    debugPrint('Found bank transfer with name: name="$recipientName" phone=$phoneNumber');
  }

  // New: Trailing phone capture for cases like "... 254706455765" at end
  if (phoneNumber == null) {
    final trailingPhoneMatch = RegExp(r'(\+?254\d{9,12})(?=\s*$)', caseSensitive: false).firstMatch(text);
    if (trailingPhoneMatch != null) {
      phoneNumber = trailingPhoneMatch.group(1);
      debugPrint('Found trailing phone: $phoneNumber');
    }
  }

  // New: Bank name extraction e.g. "Kanake Bank to M-PESA"
  if (recipientName == null) {
    final bankNameMatch = RegExp(r'^[^:]+:\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+Bank\s+to\s+M-PESA', caseSensitive: false).firstMatch(text);
    if (bankNameMatch != null) {
      recipientName = bankNameMatch.group(1);
      debugPrint('Found bank name as recipient: $recipientName');
    } else {
      final simpleBankMatch = RegExp(r'([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+(?:Bank|to)\s+M-PESA', caseSensitive: false).firstMatch(text);
      if (simpleBankMatch != null) {
        recipientName = simpleBankMatch.group(1);
        debugPrint('Found simple bank name: $recipientName');
      }
    }
  }

      // Existing "sent to NAME" or "paid to NAME" or "transfer to A/C XXXXX"
      if (recipientName == null) {
  final sentMatch =
            RegExp(r'(?:sent|paid|transfer)\s+to\s+([A-Z][^.!,\d]+)', caseSensitive: false)
                .firstMatch(text);
        if (sentMatch != null) {
          recipientName = sentMatch.group(1)!.trim();
          // Trim trailing punctuation, first name only
          recipientName = recipientName.replaceAll(RegExp(r'[^\w\s]$'), '').trim();
          if (recipientName.contains(' ')) {
            recipientName = recipientName.split(' ')[0];
          }
          debugPrint('Found recipient name (sent): $recipientName');
        }
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

  // Extract refs - more flexible for "TxRef:ABC MRef:XYZ" format
  String extraRefs = '';
  final flexibleRefMatch = RegExp(r'TxRef:([A-Z0-9]+).*?MRef:([A-Z0-9]+)', caseSensitive: false).firstMatch(text);
  if (flexibleRefMatch != null) {
    extraRefs += ' TxRef:${flexibleRefMatch.group(1)} MRef:${flexibleRefMatch.group(2)}';
  } else {
    final legacyRefMatch = RegExp(r'Transaction Ref ID:\s*([A-Z0-9]+).*?M-PESA Ref ID:\s*([A-Z0-9]+)', caseSensitive: false).firstMatch(text);
    if (legacyRefMatch != null) {
      extraRefs += ' TxRef:${legacyRefMatch.group(1)} MRef:${legacyRefMatch.group(2)}';
    }
  }
  if (phoneNumber != null) {
    extraRefs += ' $phoneNumber';
  }

  // Better description: First meaningful sentence + key info, truncate if too long
  String baseDesc = text.split('.').first.trim();
  if (baseDesc.length > 100) {
    baseDesc = '${baseDesc.substring(0, 97)}...';
  }
  final description = '$baseDesc (KES ${amount.toStringAsFixed(0)})$extraRefs';

  debugPrint('Final description: "$description"');

  return MpesaParseResult(
    transaction: Transaction(
      description: description,
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
