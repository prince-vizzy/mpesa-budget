import '../models/transaction.dart';

class MpesaParseResult {
  final Transaction transaction;
  final String? recipientName;

  MpesaParseResult({required this.transaction, this.recipientName});
}

class MpesaParser {
  static MpesaParseResult? parse(String text) {
    try {
      final normalized = text.toLowerCase();
      final looksMpesa = normalized.contains('m-pesa') ||
          normalized.contains('mpesa') ||
          normalized.contains('ksh');
      if (!looksMpesa) return null;

      // Keep expense-like events only to fit budget tracking.
      final expenseLike = normalized.contains('sent') ||
          normalized.contains('paid') ||
          normalized.contains('buy') ||
          normalized.contains('withdraw') ||
          normalized.contains('airtime');
      if (!expenseLike) return null;

      final amountMatch =
          RegExp(r'Ksh([\d,]+\.?\d*)').firstMatch(text);

      if (amountMatch == null) return null;

      final amount = double.parse(
        amountMatch.group(1)!.replaceAll(',', ''),
      );

      String? recipientName;

      // "sent to NAME" or "paid to NAME"
      final sentMatch =
          RegExp(r'(?:sent|paid)\s+to\s+([A-Za-z][A-Za-z\s]+?)(?:\s+\d|\s+on\s)', caseSensitive: false)
              .firstMatch(text);
      if (sentMatch != null) {
        recipientName = sentMatch.group(1)!.trim();
      }

      // "withdrawn from NAME" or "buy goods to NAME"
      if (recipientName == null) {
        final otherMatch =
            RegExp(r'(?:withdrawn\s+from|goods\s+to)\s+([A-Za-z][A-Za-z\s]+?)(?:\s+\d|\s+on\s)', caseSensitive: false)
                .firstMatch(text);
        if (otherMatch != null) {
          recipientName = otherMatch.group(1)!.trim();
        }
      }

      return MpesaParseResult(
        transaction: Transaction(
          description: text.split('.').first.trim(),
          amount: amount,
          date: DateTime.now(),
        ),
        recipientName: recipientName,
      );
    } catch (_) {
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
