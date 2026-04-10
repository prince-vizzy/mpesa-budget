// Standalone M-Pesa Parser Test (pure Dart, no Flutter)
// Copy of parser logic for VM testing

import 'dart:core';

class Transaction {
  final String description;
  final double amount;
  final DateTime date;
  final String? name;
  final String rawMessage;

  Transaction({
    required this.description,
    required this.amount,
    required this.date,
    this.name,
    required this.rawMessage,
  });
}

class MpesaParseResult {
  final Transaction transaction;
  final String? recipientName;
  final String rawMessage;

  MpesaParseResult({
    required this.transaction, 
    this.recipientName, 
    required this.rawMessage,
  });
}

MpesaParseResult? parse(String text) {
  print('Parsing M-Pesa text: $text');
  final normalized = text.toLowerCase();
  final looksMpesa = normalized.contains('m-pesa') ||
      normalized.contains('mpesa') ||
      normalized.contains('ksh') ||
      normalized.contains('kes');
  if (!looksMpesa) {
    print('Not an M-Pesa message');
    return null;
  }

  final expenseLike = normalized.contains('sent') ||
      normalized.contains('paid') ||
      normalized.contains('buy') ||
      normalized.contains('withdraw') ||
      normalized.contains('airtime') ||
      normalized.contains('transfer');
  if (!expenseLike) {
    print('Not an expense-like event');
    return null;
  }

  final amountMatch =
      RegExp(r'(?:Ksh|KES)\\s*([\\d,]+\\.?\\d*)', caseSensitive: false).firstMatch(text);

  if (amountMatch == null) {
    print('No amount found');
    return null;
  }

  final amount = double.parse(
    amountMatch.group(1)!.replaceAll(',', ''),
  );

  String? recipientName, phone;

  // Bank to M-PESA transfer pattern: "to 254706455765 - CHRIS MWENDA KOOME"
  final bankTransferMatch =
      RegExp(r'to\\s+(\\d{9,12})\\s*-\\s*([A-Z\\s]+)', caseSensitive: false).firstMatch(text);
  if (bankTransferMatch != null) {
    phone = bankTransferMatch.group(1);
    recipientName = bankTransferMatch.group(2)?.trim();
    print('Found bank transfer: name="$recipientName" phone=$phone');
  }

  // Existing "sent to NAME" or "paid to NAME" or "transfer to A/C XXXXX"
  if (recipientName == null) {
    final sentMatch =
        RegExp(r'(?:sent|paid|transfer)\\s+to\\s+([A-Z0-9/\\s-]+)', caseSensitive: false)
            .firstMatch(text);
    if (sentMatch != null) {
      recipientName = sentMatch.group(1)!.trim();
      if (recipientName.contains(' ')) {
        recipientName = recipientName.split(' ').first;
      }
      print('Found recipient name (sent): $recipientName');
    }
  }

  // "withdrawn from NAME" or "buy goods to NAME"
  if (recipientName == null) {
    final otherMatch =
        RegExp(r'(?:withdrawn\\s+from|goods\\s+to)\\s+([A-Z]+)', caseSensitive: false)
            .firstMatch(text);
    if (otherMatch != null) {
      recipientName = otherMatch.group(1)?.trim();
      print('Found recipient name (other): $recipientName');
    }
  }

  // Extract refs
  final refMatch = RegExp(r'TxRef:([A-Z0-9]+).*?MRef:([A-Z0-9]+)', caseSensitive: false).firstMatch(text);
  String extraRefs = '';
  if (refMatch != null) {
    extraRefs += ' TxRef:${refMatch.group(1)} MRef:${refMatch.group(2)}';
  }
  if (phone != null) {
    extraRefs += ' $phone';
  }

  final description = '${text.split('.').first.trim()}$extraRefs';

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
}

void main() {
  const sampleMessage = "Bank to M-PESA transfer of KES 1,200.00 to 254706455765 - CHRIS MWENDA KOOME successfully processed. Transaction Ref ID: 4003RFEB6099. M-PESA Ref ID: UD9GVBWDGL";

  const problematicMessage = "summdudeidk: Kanake Bank to M-PESA transfer of KES 1,200 TxRef:4003RFEB6099 MRef:UD9GVBWDGL 254706455765";

  print('Testing standard sample:');
  final result = parse(sampleMessage);
  if (result != null) {
    print('SAMPLE SUCCESS!');
    print('Name: ${result.recipientName ?? "null"}');
    print('Amount: ${result.transaction.amount}');
    print('Description: "${result.transaction.description}"');
    print('---');
  } else {
    print('SAMPLE FAILED');
  }

  print('\nTesting problematic message:');
  final problemResult = parse(problematicMessage);
  if (problemResult != null) {
    print('PROBLEM SUCCESS!');
    print('Name: ${problemResult.recipientName ?? "null"}');
    print('Amount: ${problemResult.transaction.amount}');
    print('Description: "${problemResult.transaction.description}"');
  } else {
    print('PROBLEM FAILED');
  }
}
