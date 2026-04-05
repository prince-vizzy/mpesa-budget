// lib/models/transaction.dart
class Transaction {
  final int? id;
  final String description;
  final double amount;
  final DateTime date;
  final int? categoryId;
  final String? categoryName;
  final String status;
  final String? name;
  final String? userFirstName;
  final String? rawMessage;

  Transaction({
    this.id,
    required this.description,
    required this.amount,
    required this.date,
    this.categoryId,
    this.categoryName,
    this.status = 'categorized',
    this.name,
    this.userFirstName,
    this.rawMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.millisecondsSinceEpoch,
      'category_id': categoryId,
      'category_name': categoryName,
      'status': status,
      'name': name,
      'user_first_name': userFirstName,
      'raw_message': rawMessage,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      description: map['description'] ?? '',
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      categoryId: map['category_id'] as int?,
      categoryName: map['category_name'] as String?,
      status: map['status'] as String? ?? 'categorized',
      name: map['name'] as String?,
      userFirstName: map['user_first_name'] as String?,
      rawMessage: map['raw_message'] as String?,
    );
  }
}