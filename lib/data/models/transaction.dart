enum TransactionType {
  baki,
  payment;

  static TransactionType fromString(String value) {
    if (value.toLowerCase() == 'payment') return TransactionType.payment;
    return TransactionType.baki;
  }

  String toDbString() => name;
}

class AppTransaction {
  final String id;
  final String userId;
  final String customerId;
  final TransactionType type;
  final double amount;
  final String? description;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppTransaction({
    required this.id,
    required this.userId,
    required this.customerId,
    required this.type,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isBaki => type == TransactionType.baki;
  bool get isPayment => type == TransactionType.payment;

  AppTransaction copyWith({
    String? id,
    String? userId,
    String? customerId,
    TransactionType? type,
    double? amount,
    String? description,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      customerId: customerId ?? this.customerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // SQLite Mapping (snake_case)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'customer_id': customerId,
      'type': type.toDbString(),
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      customerId: map['customer_id'] as String,
      type: TransactionType.fromString(map['type'] as String),
      amount: (map['amount'] is num)
          ? (map['amount'] as num).toDouble()
          : double.parse(map['amount'].toString()),
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Supabase JSON Mapping (snake_case)
  Map<String, dynamic> toJson() => toMap();

  factory AppTransaction.fromJson(Map<String, dynamic> json) =>
      AppTransaction.fromMap(json);
}

// Alias for backward compatibility
typedef TransactionModel = AppTransaction;
