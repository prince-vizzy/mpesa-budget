class MpesaTransaction {
  final int? id;
  final String type;
  final double amount;
  final String phoneNumber;
  final String? name;
  final String? transactionId;
  final DateTime timestamp;
  final String? message;
  String? category;
  final String? userFirstName;

  MpesaTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.phoneNumber,
    this.name,
    this.transactionId,
    required this.timestamp,
    this.message,
    this.category,
    this.userFirstName,
  });

  MpesaTransaction copyWith({
    int? id,
    String? type,
    double? amount,
    String? phoneNumber,
    String? name,
    String? transactionId,
    DateTime? timestamp,
    String? message,
    String? category,
    String? userFirstName,
  }) {
    return MpesaTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      transactionId: transactionId ?? this.transactionId,
      timestamp: timestamp ?? this.timestamp,
      message: message ?? this.message,
      category: category ?? this.category,
      userFirstName: userFirstName ?? this.userFirstName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'phoneNumber': phoneNumber,
      'name': name,
      'transactionId': transactionId,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'category': category,
      'user_first_name': userFirstName,
    };
  }

  factory MpesaTransaction.fromMap(Map<String, dynamic> map) {
    return MpesaTransaction(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: map['amount'] as double,
      phoneNumber: map['phoneNumber'] as String,
      name: map['name'] as String?,
      transactionId: map['transactionId'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      message: map['message'] as String?,
      category: map['category'] as String?,
      userFirstName: map['user_first_name'] as String?,
    );
  }
}