import 'dart:io';
import 'lib/services/mpesa_parser.dart';
import 'lib/models/transaction.dart';

void main() {
  // Standard test
  const sampleMessage = "Bank to M-PESA transfer of KES 1,200.00 to 254706455765 - CHRIS MWENDA KOOME successfully processed. Transaction Ref ID: 4003RFEB6099. M-PESA Ref ID: UD9GVBWDGL";

  // Problematic test case
  const problematicMessage = "summdudeidk: Kanake Bank to M-PESA transfer of KES 1,200 TxRef:4003RFEB6099 MRef:UD9GVBWDGL 254706455765";

  print('Testing sample:');
  print(sampleMessage);
  print('---');

  final result = MpesaParser.parse(sampleMessage);
  if (result != null) {
    print('SUCCESS!');
    print('Name: ${result.recipientName}');
    print('Amount: ${result.transaction.amount}');
    print('Description: ${result.transaction.description}');
    print('Full result: $result');
  } else {
    print('FAILED to parse');
  }
  
  print('\n--- Testing problematic message ---');
  final problemResult = MpesaParser.parse(problematicMessage);
  if (problemResult != null) {
    print('PROBLEM SUCCESS!');
    print('Name: ${problemResult.recipientName}');
    print('Amount: ${problemResult.transaction.amount}');
    print('Description: ${problemResult.transaction.description}');
  } else {
    print('FAILED to parse problematic message');
  }
}
