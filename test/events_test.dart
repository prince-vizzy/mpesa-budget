import 'package:flutter_test/flutter_test.dart';
// sqflite exports its own Transaction (a DB transaction handle).
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:mpesa_tracker/database/database_helper.dart';
import 'package:mpesa_tracker/models/budget_event.dart';
import 'package:mpesa_tracker/models/category.dart';
import 'package:mpesa_tracker/models/transaction.dart';

/// An event owns a window in time: payments inside it belong to the event and
/// are kept out of the everyday budgets.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DatabaseHelper.instance;
  late int foodId;

  // A fixed window so tests never race the clock.
  final start = DateTime(2026, 9, 12, 14, 0);
  final end = DateTime(2026, 9, 12, 23, 0);

  Transaction payment(String? name, double amount, DateTime at) => Transaction(
        description: 'TIJ${amount.toInt()}XYZ Confirmed (KES $amount)',
        amount: amount,
        date: at,
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

  Future<int> makeEvent({
    String name = 'Wanjiru wedding',
    DateTime? startsAt,
    DateTime? endsAt,
    List<String> categories = const ['Catering'],
  }) {
    return db.createEvent(BudgetEvent(
      name: name,
      startsAt: startsAt ?? start,
      endsAt: endsAt ?? end,
      createdAt: DateTime(2026, 9, 1),
      categories: [
        for (final c in categories)
          EventCategory(eventId: 0, name: c, budget: 10000),
      ],
    ));
  }

  Future<BudgetEvent> loadEvent(int id) async {
    final events = await db.getEvents();
    return events.firstWhere((e) => e.id == id);
  }

  setUp(() async {
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
    await DatabaseHelper.resetForTesting(inMemoryDatabasePath);

    await db.insertCategory(category('Food', 500));
    foodId = (await db.getAllCategories()).first.id!;
  });

  test('a payment inside the window is held for the event', () async {
    final eventId = await makeEvent();

    final intake = await db.insertParsedTransaction(
      payment('NAIVAS LIMITED', 2000, DateTime(2026, 9, 12, 16, 30)),
    );

    expect(intake.isEventSpending, isTrue);
    expect(intake.eventName, 'Wanjiru wedding');
    // It waits in the event's own queue, not the everyday one.
    expect(await db.getUncategorizedTransactions(), isEmpty);
    expect(await db.getEventQueue(eventId), hasLength(1));
  });

  test('a payment outside the window is untouched by the event', () async {
    await makeEvent();

    final intake = await db.insertParsedTransaction(
      payment('NAIVAS LIMITED', 2000, DateTime(2026, 9, 13, 9, 0)),
    );

    expect(intake.isEventSpending, isFalse);
    expect(await db.getUncategorizedTransactions(), hasLength(1));
  });

  test('the window is inclusive at both ends', () async {
    final eventId = await makeEvent();

    await db.insertParsedTransaction(payment('A', 10, start));
    await db.insertParsedTransaction(payment('B', 20, end));
    // One minute past the end belongs to nobody.
    await db.insertParsedTransaction(
      payment('C', 30, end.add(const Duration(minutes: 1))),
    );

    expect(await db.getEventQueue(eventId), hasLength(2));
    expect(await db.getUncategorizedTransactions(), hasLength(1));
  });

  test('a recipient rule cannot claim a payment made during an event', () async {
    // Teach the app that NAIVAS is Food, the way it normally would.
    await db.insertParsedTransaction(
      payment('NAIVAS LIMITED', 500, DateTime(2026, 9, 1, 10, 0)),
    );
    final queued = await db.getUncategorizedTransactions();
    await db.categorizeTransaction(
      transactionId: queued.first['id'] as int,
      categoryId: foodId,
    );
    expect(await db.getRecipientCategories(), isNotEmpty);

    final eventId = await makeEvent();

    final intake = await db.insertParsedTransaction(
      payment('NAIVAS LIMITED', 3000, DateTime(2026, 9, 12, 18, 0)),
    );

    // The event wins: this is event spending, not groceries.
    expect(intake.isEventSpending, isTrue);
    expect(intake.wasAutoCategorized, isFalse);
    expect(await db.getEventQueue(eventId), hasLength(1));
  });

  test('filing a payment counts towards the event, not the normal budgets',
      () async {
    final eventId = await makeEvent();
    await db.insertParsedTransaction(
      payment('CATERER', 4000, DateTime(2026, 9, 12, 17, 0)),
    );

    var event = await loadEvent(eventId);
    final queue = await db.getEventQueue(eventId);
    await db.categorizeEventTransaction(
      transactionId: queue.first['id'] as int,
      eventCategoryId: event.categories.first.id!,
    );

    event = await loadEvent(eventId);
    expect(event.spent, 4000);
    expect(event.categories.first.spent, 4000);

    // The everyday budgets must not see it.
    expect((await db.getCategorySpendRollups())[foodId], isNull);
    final byName = await db.getCategorySpendingByDays(3650);
    expect(byName.containsKey('Catering'), isFalse);
  });

  test('overlapping windows are refused', () async {
    await makeEvent();

    final clash = await db.overlappingEvent(
      DateTime(2026, 9, 12, 20, 0),
      DateTime(2026, 9, 13, 2, 0),
    );
    expect(clash, isNotNull);
    expect(clash!.name, 'Wanjiru wedding');

    // Butting up against the end without covering it is fine.
    final after = await db.overlappingEvent(
      DateTime(2026, 9, 12, 23, 1),
      DateTime(2026, 9, 13, 2, 0),
    );
    expect(after, isNull);
  });

  test('deleting an event keeps its payments and returns them to the queue',
      () async {
    final eventId = await makeEvent();
    await db.insertParsedTransaction(
      payment('CATERER', 4000, DateTime(2026, 9, 12, 17, 0)),
    );
    final event = await loadEvent(eventId);
    final queue = await db.getEventQueue(eventId);
    await db.categorizeEventTransaction(
      transactionId: queue.first['id'] as int,
      eventCategoryId: event.categories.first.id!,
    );
    // One filed, one still waiting.
    await db.insertParsedTransaction(
      payment('DECOR', 1500, DateTime(2026, 9, 12, 19, 0)),
    );

    await db.deleteEvent(eventId);

    expect(await db.getEvents(), isEmpty);
    // Both are real spending, so both survive — now as ordinary work to do.
    final remaining = await db.getUncategorizedTransactions();
    expect(remaining, hasLength(2));
    expect(await db.getEventTransactions(eventId), isEmpty);
  });

  test('deleting a line item returns its payments to the event queue', () async {
    final eventId = await makeEvent(categories: ['Catering', 'Decor']);
    await db.insertParsedTransaction(
      payment('CATERER', 4000, DateTime(2026, 9, 12, 17, 0)),
    );

    var event = await loadEvent(eventId);
    final catering = event.categories.firstWhere((c) => c.name == 'Catering');
    final queue = await db.getEventQueue(eventId);
    await db.categorizeEventTransaction(
      transactionId: queue.first['id'] as int,
      eventCategoryId: catering.id!,
    );
    expect(await db.getEventQueue(eventId), isEmpty);

    await db.deleteEventCategory(catering.id!);

    event = await loadEvent(eventId);
    expect(event.categories, hasLength(1));
    // Back to the event's queue, still the event's money.
    expect(await db.getEventQueue(eventId), hasLength(1));
    expect(await db.getUncategorizedTransactions(), isEmpty);
  });

  test('event totals roll up across its categories', () async {
    final eventId = await makeEvent(categories: ['Catering', 'Decor']);
    var event = await loadEvent(eventId);
    expect(event.budget, 20000);

    for (final amount in [4000.0, 2500.0]) {
      await db.insertParsedTransaction(
        payment('V$amount', amount, DateTime(2026, 9, 12, 17, 0)),
      );
    }

    final queue = await db.getEventQueue(eventId);
    expect(queue, hasLength(2));
    for (var i = 0; i < queue.length; i++) {
      await db.categorizeEventTransaction(
        transactionId: queue[i]['id'] as int,
        eventCategoryId: event.categories[i].id!,
      );
    }

    event = await loadEvent(eventId);
    expect(event.spent, 6500);
    expect(event.usage, closeTo(0.325, 0.0001));
    expect(event.isOverBudget, isFalse);
  });
}
