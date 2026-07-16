
class TreasuryTransaction {
  final int? id;
  final double amount;
  final String type;
  final String description;
  final DateTime? createdAt;

  const TreasuryTransaction({
    this.id,
    required this.amount,
    required this.type,
    required this.description,
    this.createdAt,
  });

  factory TreasuryTransaction.fromMap(Map<String, dynamic> map) {
    return TreasuryTransaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type']?.toString() ?? map['category']?.toString() ?? map['transaction_type']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'type': type,
      'description': description,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  TreasuryTransaction copyWith({
    int? id,
    double? amount,
    String? type,
    String? description,
    DateTime? createdAt,
  }) {
    return TreasuryTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreasuryTransaction && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TreasuryTransaction(id: $id, amount: $amount, type: $type, description: $description)';
}
