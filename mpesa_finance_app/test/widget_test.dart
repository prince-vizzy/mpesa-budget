import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpesa_finance_app/main.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FinanceApp());
    expect(find.text('M-Pesa Tracker'), findsOneWidget);
  });
}