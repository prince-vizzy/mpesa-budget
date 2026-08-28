import 'package:flutter_test/flutter_test.dart';
// sqflite exports its own Transaction (a DB transaction handle).
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:mpesa_tracker/database/database_helper.dart';
import 'package:mpesa_tracker/models/category.dart';
import 'package:mpesa_tracker/models/transaction.dart';

/// Covers auto-categorization of repeat payments: the rule is written when the
/// user categorizes, and applied on arrival next time.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DatabaseHelper.instance;
  late int foodId;
  late int transportId;

  Transaction payment(String? name, double amount) => Transaction(
        // The description carries the M-Pesa code, which is what makes each
        // transaction distinct to the duplicate check.
        description: 'TIJ${amount.toInt()}XYZ Confirmed (KES $amount)',
        amount: amount,
        date: DateTime.now(),
        name: name,
        rawMessage: 'raw',
      );

  Category category(String name, double budget) => Category(
        name: name,
        dailyBudget: budget,
        weeklyBudget: budget * 7,
        spentToday: 0,
        spentThisWeek: 0,
        spentThisYear: 0,
      );

  Future<int> uncategorizedCount() async =>
      (await db.getUncategorizedTransactions()).length;

  setUp(() async {
    // A fresh in-memory database per test.
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
    await DatabaseHelper.resetForTesting(inMemoryDatabasePath);

    await db.insertCategory(category('Food', 500));
    await db.insertCategory(category('Transport', 300));
    final categories = await db.getAllCategories();
    foodId = categories.firstWhere((c) => c.name == 'Food').id!;
    transportId = categories.firstWhere((c) => c.name == 'Transport').id!;
  });

  group('normalizeRecipient', () {
    test('folds the casing and punctuation the parser leaves behind', () {
      const expected = 'NAIVAS LIMITED';
      expect(DatabaseHelper.normalizeRecipient('Naivas Limited'), expected);
      expect(DatabaseHelper.normalizeRecipient('NAIVAS LIMITED.'), expected);
      expect(DatabaseHelper.normalizeRecipient('  naivas   limited '), expected);
    });

    test('treats an unnamed payee as having no key', () {
      expect(DatabaseHelper.normalizeRecipient(null), isNull);
      expect(DatabaseHelper.normalizeRecipient('   '), isNull);
      expect(DatabaseHelper.normalizeRecipient('...'), isNull);
    });
  });

  test('first payment to a new payee is queued for the user', () async {
    final intake = await db.insertParsedTransaction(payment('NAIVAS LIMITED', 200));

    expect(intake.wasAutoCategorized, isFalse);
    expect(intake.wasDuplicate, isFalse);
    expect(await uncategorizedCount(), 1);
  });

  test('categorizing a payment files the next one automatically', () async {
    await db.insertParsedTransaction(payment('NAIVAS LIMITED', 200));
    final queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
    );

    final intake = await db.insertParsedTransaction(payment('NAIVAS LIMITED', 350));

    expect(intake.wasAutoCategorized, isTrue);
    expect(intake.categoryName, 'Food');
    // It skipped the queue entirely and counts towards the budget, alongside
    // the 200 the user categorized by hand.
    expect(await uncategorizedCount(), 0);
    expect((await db.getCategorySpendRollups())[foodId]?.today, 550);
  });

  test('the rule survives the wording differences between messages', () async {
    await db.insertParsedTransaction(payment('Naivas Limited', 200));
    final queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
    );

    // Same payee, as the parser renders it from a differently worded message.
    final intake = await db.insertParsedTransaction(payment('NAIVAS LIMITED.', 350));

    expect(intake.wasAutoCategorized, isTrue);
    expect(intake.categoryName, 'Food');
  });

  test('re-categorizing corrects the rule for later payments', () async {
    await db.insertParsedTransaction(payment('NAIVAS LIMITED', 200));
    var queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
    );

    // The auto-filed one is in `transactions`; the user moves it to Transport.
    await db.insertParsedTransaction(payment('NAIVAS LIMITED', 350));
    final filed = await db.getAllCategorizedTransactions();
    final wrong = filed.firstWhere((t) => t.amount == 350);
    await db.categorizeTransaction(
      transactionId: wrong.id!,
      categoryId: transportId,
    );

    final intake = await db.insertParsedTransaction(payment('NAIVAS LIMITED', 500));
    expect(intake.categoryName, 'Transport');
  });

  test('a one-off correction leaves the rule alone', () async {
    await db.insertParsedTransaction(payment('NAIVAS LIMITED', 200));
    final queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
      rememberRecipient: false,
    );

    final intake = await db.insertParsedTransaction(payment('NAIVAS LIMITED', 350));
    expect(intake.wasAutoCategorized, isFalse);
  });

  test('forgetting a rule sends the payee back to the queue', () async {
    await db.insertParsedTransaction(payment('NAIVAS LIMITED', 200));
    final queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
    );

    await db.forgetRecipientCategory('naivas limited');

    final intake = await db.insertParsedTransaction(payment('NAIVAS LIMITED', 350));
    expect(intake.wasAutoCategorized, isFalse);
    expect(await db.getRecipientCategories(), isEmpty);
  });

  test('a transaction with no payee name is never auto-categorized', () async {
    await db.insertParsedTransaction(payment(null, 200));
    final queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
    );

    // Nothing to key a rule on, so none was written.
    expect(await db.getRecipientCategories(), isEmpty);

    final intake = await db.insertParsedTransaction(payment(null, 350));
    expect(intake.wasAutoCategorized, isFalse);
  });

  test('the same message arriving twice is only stored once', () async {
    final duplicate = payment('NAIVAS LIMITED', 200);

    expect((await db.insertParsedTransaction(duplicate)).wasDuplicate, isFalse);
    expect((await db.insertParsedTransaction(duplicate)).wasDuplicate, isTrue);
    expect(await uncategorizedCount(), 1);
  });

  test('a duplicate is caught once the rule has moved it out of the queue',
      () async {
    await db.insertParsedTransaction(payment('NAIVAS LIMITED', 200));
    final queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
    );

    // Auto-filed transactions land in `transactions`, so the duplicate check
    // has to look there too.
    final repeat = payment('NAIVAS LIMITED', 350);
    expect((await db.insertParsedTransaction(repeat)).wasAutoCategorized, isTrue);
    expect((await db.insertParsedTransaction(repeat)).wasDuplicate, isTrue);
    expect((await db.getAllCategorizedTransactions()).length, 2);
  });
}
