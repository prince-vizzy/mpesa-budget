// lib/models/transaction.dart
class Transaction {
  final int? id;
  final String description;
  final double amount;
  final DateTime date;
  final int? categoryId;
  final String? categoryName;
  final String status;

  Transaction({
    this.id,
    required this.description,
    required this.amount,
    required this.date,
    this.categoryId,
    this.categoryName,
    this.status = 'categorized',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'category_id': categoryId,
      'category_name': categoryName, // Added to match DB
      'status': status,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      description: map['description'] ?? '',
      // Safely convert num to double
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      categoryId: map['category_id'] as int?,
      categoryName: map['category_name'] as String?,
      status: map['status'] as String? ?? 'categorized',
    );
  }
}