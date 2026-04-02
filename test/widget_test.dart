import 'package:flutter_test/flutter_test.dart';
import 'package:mpesa_tracker/services/mpesa_parser.dart';

void main() {
  test('MpesaParser parses expense-like message', () {
    final result = MpesaParser.parse(
      'Confirmed. Ksh1,250.00 sent to JOHN DOE on 01/04/26 at 10:30 AM. New M-PESA balance is Ksh4,500.00',
    );
    expect(result, isNotNull);
    expect(result!.transaction.amount, 1250.00);
    expect(result.transaction.description.isNotEmpty, isTrue);
    expect(result.recipientName, 'JOHN DOE');
  });

  test('MpesaParser ignores non-mpesa text', () {
    final result = MpesaParser.parse('Hello team, meeting moved to 3 PM.');
    expect(result, isNull);
  });
}
