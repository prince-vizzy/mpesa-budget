import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/budget_event.dart';
import '../models/transaction.dart';

/// Events and their line items.
///
/// Kept apart from [CategoryStore] on purpose: event spending is budgeted and
/// reported separately from the everyday categories, and mixing the two states
/// is how that separation quietly rots.
class EventStore with ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<BudgetEvent> _events = [];
  Map<int, int> _queueCounts = {};
  bool _loading = true;

  EventStore() {
    load();
  }

  List<BudgetEvent> get events => _events;
  bool get loading => _loading;

  BudgetEvent? get activeEvent {
    final now = DateTime.now();
    for (final event in _events) {
      if (event.isActiveAt(now)) return event;
    }
    return null;
  }

  List<BudgetEvent> get upcoming {
    final now = DateTime.now();
    return _events.where((e) => e.startsAt.isAfter(now)).toList().reversed.toList();
  }

  List<BudgetEvent> get past {
    final now = DateTime.now();
    return _events.where((e) => e.hasEndedBy(now)).toList();
  }

  /// How many payments an event has captured that still need a line item.
  int queueCountFor(int? eventId) => eventId == null ? 0 : _queueCounts[eventId] ?? 0;

  /// Total across every event — what the tab badge shows.
  int get totalQueued =>
      _queueCounts.values.fold(0, (sum, count) => sum + count);

  Future<void> load() async {
    _events = await _db.getEvents();

    final counts = <int, int>{};
    for (final event in _events) {
      if (event.id == null) continue;
      final queue = await _db.getEventQueue(event.id!);
      if (queue.isNotEmpty) counts[event.id!] = queue.length;
    }
    _queueCounts = counts;

    _loading = false;
    notifyListeners();
  }

  /// Why a window cannot be used, or null when it is fine.
  ///
  /// Overlapping windows would make attribution ambiguous — a payment would
  /// belong to two events at once — so this is checked before saving rather
  /// than resolved afterwards.
  Future<String?> validateWindow(
    DateTime startsAt,
    DateTime endsAt, {
    int? exceptId,
  }) async {
    if (!endsAt.isAfter(startsAt)) {
      return 'The end has to come after the start.';
    }

    final clash = await _db.overlappingEvent(startsAt, endsAt, exceptId: exceptId);
    if (clash != null) {
      return '"${clash.name}" already covers part of that window.';
    }
    return null;
  }

  Future<int> createEvent(BudgetEvent event) async {
    final id = await _db.createEvent(event);
    await load();
    return id;
  }

  Future<void> updateEvent(BudgetEvent event) async {
    await _db.updateEvent(event);
    await load();
  }

  Future<void> deleteEvent(int eventId) async {
    await _db.deleteEvent(eventId);
    await load();
  }

  Future<void> addCategory(int eventId, String name, double budget) async {
    await _db.addEventCategory(eventId, name, budget);
    await load();
  }

  Future<void> updateCategory(EventCategory category) async {
    await _db.updateEventCategory(category);
    await load();
  }

  Future<void> deleteCategory(int categoryId) async {
    await _db.deleteEventCategory(categoryId);
    await load();
  }

  Future<List<Transaction>> transactionsFor(int eventId) =>
      _db.getEventTransactions(eventId);

  Future<List<Map<String, dynamic>>> queueFor(int eventId) =>
      _db.getEventQueue(eventId);

  Future<void> fileTransaction({
    required int transactionId,
    required int eventCategoryId,
  }) async {
    await _db.categorizeEventTransaction(
      transactionId: transactionId,
      eventCategoryId: eventCategoryId,
    );
    await load();
  }
}
