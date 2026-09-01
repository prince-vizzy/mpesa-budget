// lib/models/budget_event.dart

/// A one-off occasion with its own budget — a wedding, a funeral, a trip.
///
/// An event owns a window in time. Any M-Pesa payment that lands between
/// [startsAt] and [endsAt] belongs to it, which is why the end is a full
/// timestamp rather than a date: an event that runs 2pm to 11pm should not
/// swallow the whole day's spending.
///
/// Event spending is deliberately kept out of the normal category budgets, so a
/// big weekend does not make the everyday numbers meaningless.
class BudgetEvent {
  final int? id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;

  /// Line items for this event. Empty when only the event row was loaded.
  final List<EventCategory> categories;

  const BudgetEvent({
    this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    this.categories = const [],
  });

  Duration get duration => endsAt.difference(startsAt);

  bool containsMoment(DateTime moment) =>
      !moment.isBefore(startsAt) && !moment.isAfter(endsAt);

  bool isActiveAt(DateTime now) => containsMoment(now);

  bool hasEndedBy(DateTime now) => now.isAfter(endsAt);

  /// What the line items add up to. Zero when nothing was budgeted.
  double get budget =>
      categories.fold(0.0, (sum, category) => sum + category.budget);

  double get spent =>
      categories.fold(0.0, (sum, category) => sum + category.spent);

  /// Null when nothing was budgeted — a ratio against zero says nothing.
  double? get usage => budget > 0 ? spent / budget : null;

  bool get isOverBudget => budget > 0 && spent > budget;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'starts_at': startsAt.millisecondsSinceEpoch,
        'ends_at': endsAt.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static BudgetEvent fromMap(
    Map<String, dynamic> map, {
    List<EventCategory> categories = const [],
  }) {
    return BudgetEvent(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Event',
      startsAt: DateTime.fromMillisecondsSinceEpoch(map['starts_at'] as int),
      endsAt: DateTime.fromMillisecondsSinceEpoch(map['ends_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? map['starts_at'] as int,
      ),
      categories: categories,
    );
  }

  BudgetEvent copyWith({
    String? name,
    DateTime? startsAt,
    DateTime? endsAt,
    List<EventCategory>? categories,
  }) {
    return BudgetEvent(
      id: id,
      name: name ?? this.name,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      createdAt: createdAt,
      categories: categories ?? this.categories,
    );
  }
}

/// A line item inside an event. Unlike the app's normal categories these carry
/// a single amount for the whole event rather than a daily or monthly budget,
/// and they exist only as long as the event does.
class EventCategory {
  final int? id;
  final int eventId;
  final String name;
  final double budget;

  /// Summed from the transactions filed under it, not stored.
  final double spent;

  const EventCategory({
    this.id,
    required this.eventId,
    required this.name,
    this.budget = 0,
    this.spent = 0,
  });

  double? get usage => budget > 0 ? spent / budget : null;

  bool get isOverBudget => budget > 0 && spent > budget;

  double get remaining => budget - spent;

  Map<String, dynamic> toMap() => {
        'id': id,
        'event_id': eventId,
        'name': name,
        'budget': budget,
      };

  static EventCategory fromMap(Map<String, dynamic> map, {double spent = 0}) {
    return EventCategory(
      id: map['id'] as int?,
      eventId: map['event_id'] as int,
      name: map['name'] as String? ?? '',
      budget: (map['budget'] as num? ?? 0).toDouble(),
      spent: spent,
    );
  }

  EventCategory copyWith({String? name, double? budget, double? spent}) {
    return EventCategory(
      id: id,
      eventId: eventId,
      name: name ?? this.name,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
    );
  }
}
